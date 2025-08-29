# modules/terraform-knowledge-base/variables.tf

variable "assistant_arn" {
  description = "The ARN of the Wisdom assistant to associate."
  type        = string
}

variable "connect_instance_id" {
  description = "The ID of the Amazon Connect instance."
  type        = string
}

variable "prompt_model_id" {
  description = "AI Prompt Model ID"
  type        = string
}

variable "region" {
  description = "The AWS region where resources will be created."
  type        = string
}

variable "locale" {
  description = "Wisdom AI locale Key"
  type        = string
}

variable "self_service_pre_processing_prompt_content" {
  description = "Self Service Pre Processing Prompt Content by Locales"
  type        = string
}

variable "self_service_answer_generation_prompt_content" {
  description = "Self Service Answer Generation Prompt Content by Locales"
  type        = string
}

variable "env" {
  description = "env"
  type = string
}