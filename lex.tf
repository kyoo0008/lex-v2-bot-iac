
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
  # Zip 파일 내부의 `qic-test-bot/Bot.json` 파일에 정의된 'name'과 일치해야 합니다.
  name                          = "qic-test-bot" 
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

  # Lexbot에 이 태그가 달려있어야 Connect instance 내부에서 보임 
  bot_tags = [{ 
    key   = "AmazonConnectEnabled"
    value = "True"
  }]

  depends_on = [
    aws_s3_object.bot_definition_upload,
    awscc_wisdom_assistant.example,
  ]
}
