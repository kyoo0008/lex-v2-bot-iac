
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

# --- 2. 봇 정의 파일을 저장할 S3 버킷 생성 ---
resource "aws_s3_bucket" "lex_bot_bucket" {
  bucket = "lex-bot-definition-bucket-${random_pet.bucket_suffix.id}"
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

  # 2. 동적으로 수정한 Intent.json의 내용을 압축에 포함
  source {
    content  = local.modified_intent_json_string
    # zip 파일 내의 경로 (폴더 구조 유지)
    filename = local.relative_intent_path 
  }
}

# S3 업로드
resource "aws_s3_object" "bot_definition_upload" {
  bucket = aws_s3_bucket.lex_bot_bucket.id
  key    = "bot-definition-final.zip"
  source = data.archive_file.bot_zip.output_path
  source_hash = filemd5(data.archive_file.bot_zip.output_path)
}

# Lex 봇 생성
resource "awscc_lex_bot" "bot_from_folder" {
  # `${local.lex_bot_name}/Bot.json` 파일에 정의된 'name'과 일치해야 합니다.
  name                          = "${local.lex_bot_name}" 
  data_privacy = {
    child_directed = false
  }
  idle_session_ttl_in_seconds   = 300
  role_arn                      = aws_iam_role.lex_role.arn
  auto_build_bot_locales        = true

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
    awscc_wisdom_assistant.example,
  ]
}


# Check and Configure Association for each Bot
# resource "terraform_data" "connect_bot_association" {
#   # for_each = {
#   #   for idx, bot in local.connect_bot_associations :
#   #   bot.bot_name => bot
#   # }

#   # triggers_replace = [
#   #   timestamp()
#   # ]

#   input = {
#     bot_name = local.lex_bot_name
#     bot_id = awscc_lex_bot.bot_from_folder.bot_id

#   }

#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command     = <<-EOT
#       set -e

#       BOT_NAME="${self.input.bot_name}"
#       BOT_ID="${self.input.bot_id}"
#       RELEASE_ALIAS_ARN="${each.value.alias_arn}"
#       TEST_ALIAS_ARN="${each.value.test_alias_arn != null ? each.value.test_alias_arn : ""}"
#       INSTANCE_ID="${data.aws_connect_instance.connect_instance.id}"
#       REGION="${var.region}"

#       echo "Checking connected bots for $BOT_NAME..."

#       # Get connected bots for the current bot_id
#       CONNECTED_BOTS=$(aws connect list-bots \
#         --instance-id "$INSTANCE_ID" \
#         --lex-version "V2" \
#         --region "$REGION" \
#         --query "LexBots[?contains(LexV2Bot.AliasArn, '$BOT_ID')].LexV2Bot.AliasArn" \
#         --output json)

#       echo "Connected bots: $CONNECTED_BOTS"

#       # Function to associate a bot alias
#       associate_bot_alias() {
#         ALIAS_ARN="$1"
#         ALIAS_TYPE="$2"

#         if echo "$CONNECTED_BOTS" | jq -e --arg arn "$ALIAS_ARN" 'contains([$arn])' > /dev/null; then
#           echo "$ALIAS_TYPE Alias is already connected for $BOT_NAME"
#         else
#           echo "Connecting $ALIAS_TYPE Alias for $BOT_NAME..."
#           aws connect associate-bot \
#             --instance-id "$INSTANCE_ID" \
#             --lex-v2-bot "{
#               \"AliasArn\": \"$ALIAS_ARN\"
#             }" \
#             --region "$REGION"

#           if [ $? -eq 0 ]; then
#             echo "$ALIAS_TYPE Alias connection completed successfully for $BOT_NAME"
#           else
#             echo "Failed to connect $ALIAS_TYPE Alias for $BOT_NAME"
#             exit 1
#           fi
#           sleep 5 # Wait to avoid quota issues
#         fi
#       }

#       associate_bot_alias "$RELEASE_ALIAS_ARN" "Release"

#       if [ ! -z "$TEST_ALIAS_ARN" ] && [ "$TEST_ALIAS_ARN" != "null" ]; then
#         associate_bot_alias "$TEST_ALIAS_ARN" "Test"
#       fi
#     EOT
#   }

#   depends_on = [
#     awscc_lex_bot.bot_from_folder
#   ]
# }
