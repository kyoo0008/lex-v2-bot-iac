
# 로케일별 Assistant 생성
resource "awscc_wisdom_assistant" "locale_assistants" {
  for_each = toset(local.locales)

  name = "${local.wisdom_assistant_prefix}-${each.key}" # 예: qconnect-assistant-ko_KR
  type = "AGENT"
  server_side_encryption_configuration = {
    kms_key_id = data.aws_kms_key.example.arn
  }
  tags = [
    {
      key   = "AmazonConnectEnabled"
      value = "True"
    },
    {
      key   = "locale"
      value = "${each.key}"
    }
  ]

}

# 로케일별 AI 기능(프롬프트, 에이전트) 관리자
resource "terraform_data" "wisdom_ai_manager" {
  for_each = awscc_wisdom_assistant.locale_assistants

  
  triggers_replace = [
    each.value,
    local.prompt_model_id,
    filemd5("${path.module}/scripts/manage_wisdom_ai.sh"),
    jsonencode(local.agent_configs), # jsonencode로 변경하여 map 순서에 따른 불필요한 변경 방지
    local.env,
    # env에 따라 트리거 소스를 변경합니다. dev 환경에서는 모든 프롬프트 파일 내용의 해시를 사용합니다.
    md5(local.env == "dev" ? jsonencode({ for k, v in data.local_file.prompts : k => v.content_base64 }) : file("${path.module}/deployment_vars.json"))
  ]

  input = {
    assistant_id   = each.value.assistant_id
    model_id       = local.prompt_model_id
    region         = var.region
    # 각 로케일별로 고유한 에이전트 이름 부여
    locale         = each.key # for_each의 key가 로케일
    env            = local.env,
    
    agents_json = jsonencode(local.agent_configs)

    prompts_json = local.env == "dev" ? jsonencode([
      for key, config in local.prompt_configs : {
        prompt_name       = config.prompt_name_local
        # "ko_KR.self_service_pre_processing" 형식의 키를 사용하여 로케일에 맞는 파일 내용을 찾습니다.
        prompt_content    = data.local_file.prompts["${each.key}.${key}"].content
        prompt_type       = config.prompt_type
        prompt_api_format = config.prompt_api_format
        use_flag          = config.use_flag
      }
    ]) : jsonencode(lookup(local.deployment_config, each.key, { prompts = [] }).prompts)

    # prod 환경에서는 guardrail 정보도 전달 (예시)
    guardrails_json = local.env == "prod" ? jsonencode(lookup(local.deployment_config, each.key, {guardrails = []}).guardrails) : "[]"


    
  }

  provisioner "local-exec" {
    command = "chmod +x ${path.module}/scripts/manage_wisdom_ai.sh && ${path.module}/scripts/manage_wisdom_ai.sh"

    environment = {
      ASSISTANT_ID    = self.input.assistant_id
      MODEL_ID        = self.input.model_id
      REGION          = self.input.region
      LOCALE          = self.input.locale
      ENV             = self.input.env
      PROMPTS_JSON    = self.input.prompts_json
      GUARDRAILS_JSON = self.input.guardrails_json
      AGENTS_JSON     = self.input.agents_json
    }
  }

  depends_on = [
    data.local_file.prompts,
    awscc_wisdom_assistant.locale_assistants
  ]
}

# lmd_summarize_transcript 모듈 호출
module "lmd_qic_create_sessions" {
  source = "./modules/terraform-aicc-lmd-python"

  application      = var.application
  boundary         = local.boundary
  env              = local.env
  func_name        = local.qic_create_session.name
  func_description = local.qic_create_session.desc

  func_source_path     = "task/lambda_function/${local.qic_create_session.name}/src"
  func_source_zip_path = "task/lambda_function/${local.qic_create_session.name}.zip"

  func_environment_variables = {
    # ENV               = var.env
  }

  func_architecture    = ["x86_64"]
  func_runtime         = "python3.13"
  func_timeout         = 600
  func_memory_size_mb  = 128
  func_storage_size_mb = 512
  func_tracing_mode    = "PassThrough"

  
  func_inline_policy_json = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowWisdom"
        Action   = ["wisdom:*"]
        Effect   = "Allow"
        Resource = ["*"]
      }
    ]
  }
}


# -----------------------------------------------------------------------------
# Enable Q in Connect Assistant Logging
# -----------------------------------------------------------------------------

# Create a SINGLE CloudWatch Log Group for all assistants
resource "aws_cloudwatch_log_group" "qconnect_assistant_logs" {
  name              = "/aws/qconnect/assistants/all-locales"
  retention_in_days = 7
}

# Resource policy to allow the CloudWatch Logs service to deliver logs from Amazon Q
resource "aws_cloudwatch_log_resource_policy" "qconnect_delivery_policy" {
  policy_name = "qconnect-log-delivery-policy"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowQinConnectLogDelivery"
        Effect   = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.qconnect_assistant_logs.arn}:*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          },
          ArnLike = {
            "aws:SourceArn" = "arn:aws:wisdom:${var.region}:${data.aws_caller_identity.current.account_id}:assistant/*"
          }
        }
      },
    ]
  })
}



resource "aws_cloudwatch_log_delivery_source" "qconnect_assistant_source" {
  for_each     = awscc_wisdom_assistant.locale_assistants
  name         = "qconnect-source-${replace(each.key, "_", "-")}"
  resource_arn = each.value.assistant_arn
  log_type     = "EVENT_LOGS"

  depends_on = [aws_cloudwatch_log_resource_policy.qconnect_delivery_policy]
}

# Define a SINGLE CloudWatch Log Group as the destination for the logs
resource "aws_cloudwatch_log_delivery_destination" "qconnect_assistant_destination" {
  name          = "qconnect-destination-all-locales"
  output_format = "json"
  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.qconnect_assistant_logs.arn
  }
}
# destroy : aws logs delete-delivery --id {delivery_id} 를 먼저 실행
resource "aws_cloudwatch_log_delivery" "qconnect_assistant_delivery" { 
  for_each                 = awscc_wisdom_assistant.locale_assistants
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.qconnect_assistant_destination.arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.qconnect_assistant_source[each.key].name


  depends_on = [
    aws_cloudwatch_log_delivery_destination.qconnect_assistant_destination,
    aws_cloudwatch_log_delivery_source.qconnect_assistant_source
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "aws logs delete-delivery --id ${self.id}"
  }
}

