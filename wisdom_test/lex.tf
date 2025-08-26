
resource "aws_iam_role" "lex_role" {
  name = "lexv2-bot-from-local-file-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lex.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lex_policy_attachment" {
  role       = aws_iam_role.lex_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonLexFullAccess"
}

resource "aws_iam_role_policy" "runtime_inline" {
  provider = aws

  name   = "LexV2BotRuntimeInlinePolicy"
  role   = aws_iam_role.lex_role.id
  policy = jsonencode({
    Version = "2012-10-17" # IAM 정책 버전
    Statement = [
      {
        Sid    = "AllowAction"
        Effect = "Allow"
        Action = [
          "polly:SynthesizeSpeech",
        ]
        Resource = [
          "*",
        ]
      },
      {
        Sid    = "DetectSentimentPolicy"
        Effect = "Allow"
        Action = [
          "comprehend:DetectSentiment"
        ]
        Resource = [
          "*"
        ]
      },
      {
        Sid    = "CloudWatchPolicyID"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = [
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:${local.lex_bot_log_group_name}:*"
        ]
      },
      {
        Sid = "AllowWisdom"
        Effect = "Allow"
        Action = [
          "wisdom:*"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# --- 2. 봇 정의 파일을 저장할 S3 버킷 생성 ---
resource "aws_s3_bucket" "lex_bot_bucket" {
  bucket = "lex-bot-definition-bucket"
  force_destroy = false
}


data "archive_file" "bot_zip" {
  type        = "zip"
  output_path = "${path.module}/bot-definition-final.zip"

  # 1. 수정되지 않은 나머지 모든 원본 파일들을 압축에 포함
  dynamic "source" {
    for_each = local.unmodified_source_files

    content {
      # 파일 시스템 경로
      content  = file("${local.full_source_root_path}/${source.value}")
      # zip 파일 내의 경로 (폴더 구조 유지)
      filename = source.value
    }
  }

  # 2. [수정됨] 동적으로 수정한 모든 로케일의 Intent.json 내용을 압축에 포함
  dynamic "source" {
    for_each = local.intent_data_by_locale

    content {
      content  = source.value.modified_json_string
      # zip 파일 내의 경로 (폴더 구조 유지)
      filename = source.value.relative_path
    }
  }
}


# S3 업로드
resource "aws_s3_object" "bot_definition_upload" {
  bucket = aws_s3_bucket.lex_bot_bucket.id
  key    = "bot-definition-final.zip"
  source = data.archive_file.bot_zip.output_path
  source_hash = filemd5(data.archive_file.bot_zip.output_path)
}

# Lex 봇 생성(association, alias, version 연계는 나중에)
resource "awscc_lex_bot" "bot_from_folder" {
  # `${local.lex_bot_name}/Bot.json` 파일에 정의된 'name'과 일치해야 합니다.
  name                          = "${local.lex_bot_name}" 
  data_privacy = {
    child_directed = false
  }
  idle_session_ttl_in_seconds   = 300
  role_arn                      = aws_iam_role.lex_role.arn
  auto_build_bot_locales        = true # bot 자동 빌드 활성화

  bot_file_s3_location = {
    s3_bucket     = aws_s3_bucket.lex_bot_bucket.id
    s3_object_key = aws_s3_object.bot_definition_upload.key
  }

  bot_tags = [{ 
    key   = "AmazonConnectEnabled"
    value = "True"
  }]

  depends_on = [
    aws_s3_object.bot_definition_upload,
    awscc_wisdom_assistant.locale_assistants
  ]
}

resource "awscc_lex_bot_version" "bot_new_version" {
  bot_id         = awscc_lex_bot.bot_from_folder.bot_id
  bot_version_locale_specification = [
    for locale_code in local.locales : {
      locale_id = locale_code                 
      bot_version_locale_details = {
        source_bot_version = "DRAFT"
      }
    }
  ]
}



resource "awscc_lex_bot_alias" "example" {
  bot_alias_name = "ready"
  bot_id         = awscc_lex_bot.bot_from_folder.bot_id
  bot_version    = awscc_lex_bot_version.bot_new_version.bot_version
  description    = "Test bot alias for example"

  bot_alias_locale_settings = [
    for locale_code in local.locales : {
      locale_id = locale_code                 
      bot_alias_locale_setting = {
        enabled = true
        code_hook_specification = {
          lambda_code_hook = {
            lambda_arn                  = "${module.lmd_lex_hook_func.lmd_func_arn}"
            code_hook_interface_version = "1.0"
          }
        }
      }
    }
    
  ]

  sentiment_analysis_settings = {
    detect_sentiment = true
  }

  conversation_log_settings = {
    text_log_settings = [{
      enabled = true
      destination = {
        cloudwatch = {
          cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.lex_bot.arn}",
          log_prefix               = "${local.lex_bot_name}/"
        }
      }
    }]
    audio_log_settings = [{
      enabled = false
      destination = {
        s3_bucket = {
          s3_bucket_arn = "${aws_s3_bucket.lex_bot_bucket.arn}"
          log_prefix = "audio/"
        }
      }
    }]
  }



  bot_alias_tags = [
    {
      key   = "Environment"
      value = "${local.env}"
    },
    {
      key   = "Modified By"
      value = "AWSCC"
    },
    {
      key = "AmazonConnectEnabled"
      value = "True"
    }
  ]
}


resource "aws_cloudwatch_log_group" "lex_bot" {
  provider = aws

  name              = local.lex_bot_log_group_name
  # retention_in_days = 14
}


module "lmd_lex_hook_func" {
  source = "./modules/terraform-aicc-lmd-python"

  application      = var.application
  boundary         = local.boundary
  env              = local.env
  func_name        = local.lex_hook_func.name
  func_description = local.lex_hook_func.desc

  func_source_path     = "task/lambda_function/${local.lex_hook_func.name}/src"
  func_source_zip_path = "task/lambda_function/${local.lex_hook_func.name}.zip"

  func_environment_variables = {
    # ENV               = var.env
  }

  func_architecture    = ["x86_64"]
  func_runtime         = "python3.13"
  func_timeout         = 600
  func_memory_size_mb  = 128
  func_storage_size_mb = 512
  func_tracing_mode    = "PassThrough"

  
  # func_inline_policy_json = {}
}


resource "terraform_data" "associate_bot" {
  triggers_replace = [
    awscc_lex_bot.bot_from_folder,
    awscc_lex_bot_alias.example,
    awscc_lex_bot_version.bot_new_version
  ]

  input = {
    connect_instance_id = data.aws_connect_instance.connect_instance.id
    bot_alias_arn = awscc_lex_bot_alias.example.arn
    region         = var.region
  }

  

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "chmod +x ${path.module}/scripts/associate_bot.sh && ${path.module}/scripts/associate_bot.sh"
    environment = {
      CONNECT_INSTANCE_ID = self.input.connect_instance_id
      BOT_ALIAS_ARN = self.input.bot_alias_arn
      REGION = self.input.region
    }
  }

  depends_on = [
    awscc_lex_bot.bot_from_folder,
    awscc_lex_bot_alias.example,
    awscc_lex_bot_version.bot_new_version
  ]

}