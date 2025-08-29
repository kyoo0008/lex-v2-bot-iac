# modules/terraform-wisdom-ai/outputs.tf

output "self_service_agent_id_version" {
  description = "self_service_agent_id_version."
  value       = lookup(local.wisdom_ai_result, "self_service_agent_id_version", null)
}

output "ansgen_prompt_id_version" {
  description = "ansgen_prompt_id_version"
  value       = lookup(local.wisdom_ai_result, "ansgen_prompt_id_version", null)
}

output "preproc_prompt_id_version" {
  description = "preproc_prompt_id_version"
  value       = lookup(local.wisdom_ai_result, "preproc_prompt_id_version", null)
}