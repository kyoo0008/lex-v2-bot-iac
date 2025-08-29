
output "assistants" {
  description = "Locale 별 assistant"
  value       = awscc_wisdom_assistant.locale_assistants
}

output "kb_result" {
  description = "Locale 별 KB"
  value = module.knowledge_bases
}