# modules/terraform-knowledge-base/outputs.tf

output "knowledge_base_id" {
  description = "The ID of the created Knowledge Base."
  value       = lookup(local.kb_result, "knowledge_base_id", null)
}

output "knowledge_base_arn" {
  description = "The ARN of the created Knowledge Base."
  value       = lookup(local.kb_result, "knowledge_base_arn", null)
}