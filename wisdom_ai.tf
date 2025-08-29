
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
module "wisdom_ai_agents" {
  for_each = awscc_wisdom_assistant.locale_assistants

  source = "./modules/terraform-wisdom-ai"
  locale = each.key
  env = local.env
  prompt_model_id = local.prompt_model_id
  region              = var.region
  assistant_arn       = each.value.assistant_arn
  connect_instance_id = data.aws_connect_instance.connect_instance.id

  self_service_pre_processing_prompt_content = "${data.local_file.prompts["${each.key}.self_service_pre_processing"].content}"
  self_service_answer_generation_prompt_content = "${data.local_file.prompts["${each.key}.self_service_answer_generation"].content}"

  depends_on = [
    data.aws_kms_key.example,
    awscc_wisdom_assistant.locale_assistants,
    data.local_file.prompts
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

