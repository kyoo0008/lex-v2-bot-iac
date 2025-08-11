

output "lex_bot_s3_bucket_name" {
  description = "Lex Bot 정의 파일이 저장된 S3 버킷 이름"
  value       = aws_s3_bucket.lex_bot_bucket.id
}

output "lex_bot_s3_object_key" {
  description = "S3 버킷에 업로드된 파일의 Lex Bot 정의 Key"
  value       = aws_s3_object.bot_definition_upload.key
}

output "qic_kb_s3_bucket_name" {
  description = "QiC KB 파일이 저장된 S3 버킷 이름"
  value       = aws_s3_bucket.qic_kb_bucket.id
}

output "qic_kb_s3_object_key" {
  description = "S3 버킷에 업로드된 파일의 Qic KB Key"
  value       = aws_s3_object.qic_kb_documents.key
}

output "assistant_arn" {
  description = "Assistant Arn"
  value = awscc_wisdom_assistant.example.assistant_arn
}

output "data_integration_arn" {
  description = "data integration arn"
  value = awscc_appintegrations_data_integration.example.data_integration_arn
}

output "wisdom_knowledge_base_arn" {
  description = "wisdom knowledge base integration arn"
  value = awscc_wisdom_knowledge_base.example.knowledge_base_arn
}

# output "ai_prompt_arn" {
#   description = "AI Prompt Arn"
#   value = awscc_wisdom_ai_prompt.example.ai_prompt_arn
# }

# output "ai_prompt_version" {
#   description = "AI Prompt Version"
#   value = awscc_wisdom_ai_prompt.example.ai_prompt_arn
# }

