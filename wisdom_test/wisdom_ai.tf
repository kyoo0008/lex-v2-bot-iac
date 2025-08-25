# To-do : 다른 assistant, locale 끼리의 session 처리는 어떻게 할 것인지 고민...=>Flow setContactData 에서 wisdomSessionArn을 설정하여 Lex로 넘겨줌 => lambda로 구현??
# To-do : prompt yaml translator, validator
# To-do : QiC Logging 활성화 

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
resource "aws_iam_policy" "allow_wisdom" {
  name = "allow_wisdom_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["wisdom:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
resource "awscc_iam_role" "example" {
  description = "AWS IAM role for lambda function"
  assume_role_policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns         = [aws_iam_policy.allow_wisdom.arn]

}

data "archive_file" "example" {
  type        = "zip"
  source_file = "index.py"
  output_path = "lambda_function_payload.zip"
}

resource "awscc_s3_bucket" "lambda_assets" {
}

resource "aws_s3_object" "zip" {
  source = data.archive_file.example.output_path
  bucket = awscc_s3_bucket.lambda_assets.id
  key    = "index.zip"
}

resource "awscc_lambda_function" "example" {
  function_name = "qic-create-session-lmd"
  description   = "AWS Lambda function"
  code = {
    s3_bucket = awscc_s3_bucket.lambda_assets.id
    s3_key    = aws_s3_object.zip.key
  }
  package_type  = "Zip"
  handler       = "index.handler"
  runtime       = "python3.13"
  timeout       = "300"
  memory_size   = "128"
  role          = awscc_iam_role.example.arn
  architectures = ["arm64"]
  # environment = {
  #   variables = {
  #     MY_KEY_1 = "MY_VALUE_1"
  #     MY_KEY_2 = "MY_VALUE_2"
  #   }
  # }
  ephemeral_storage = {
    size = 512 # Min 512 MB and the Max 10240 MB
  }
}