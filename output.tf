

output "s3_bucket_name" {
  description = "봇 정의 파일이 저장된 S3 버킷 이름"
  value       = aws_s3_bucket.lex_bot_bucket.id
}

output "s3_object_key" {
  description = "S3 버킷에 업로드된 파일의 Key"
  value       = aws_s3_object.bot_definition_upload.key
}

output "assistant_arn" {
  description = "Assistant Arn"
  value = awscc_wisdom_assistant.example.assistant_arn
}