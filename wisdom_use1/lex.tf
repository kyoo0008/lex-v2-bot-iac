

# --- 2. 봇 정의 파일을 저장할 S3 버킷 생성 ---
resource "aws_s3_bucket" "lex_bot_bucket" {
  bucket = "${local.naming_prefix}-${var.region_code}-lex-bot-definition-bucket"
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
  etag = filemd5(data.archive_file.bot_zip.output_path)
}

# Lex 봇 생성
resource "awscc_lex_bot" "bot_from_folder" {
  # `${local.lex_bot_full_name}/Bot.json` 파일에 정의된 'name'과 일치해야 합니다.
  name                          = "${local.lex_bot_full_name}" 
  data_privacy = {
    child_directed = false
  }
  idle_session_ttl_in_seconds   = 300
  role_arn                      = data.aws_iam_role.lex_role.arn
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

  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [aws_s3_object.bot_definition_upload]
  }
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
            lambda_arn                  = "${data.aws_lambda_function.qic_apigateway_caller.arn}"
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
          log_prefix               = "${local.lex_bot_full_name}/"
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
      value = "${var.env}"
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


resource "aws_lambda_permission" "allow_lex_to_invoke_qic_api_caller" {
  statement_id  = "AllowLexV2ToInvokeQICAPICaller"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.qic_apigateway_caller.function_name
  principal     = "lexv2.amazonaws.com"
  source_arn    = "arn:aws:lex:${var.region}:${data.aws_caller_identity.current.account_id}:bot-alias/*"

  depends_on = [
    awscc_lex_bot_alias.example
  ]
}



resource "aws_cloudwatch_log_group" "lex_bot" {
  provider = aws

  name              = local.lex_bot_log_group_name
  # retention_in_days = 14
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

