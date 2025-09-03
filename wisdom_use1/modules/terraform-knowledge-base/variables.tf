# modules/terraform-knowledge-base/variables.tf

variable "env" {
  description = "env"
  type        = string
}

variable "assistant_arn" {
  description = "The ARN of the Wisdom assistant to associate."
  type        = string
}

variable "knowledge_base_name" {
  description = "The name for the knowledge base."
  type        = string
}

variable "content_path" {
  description = "The local path to the directory containing content files."
  type        = string
}

variable "connect_instance_id" {
  description = "The ID of the Amazon Connect instance."
  type        = string
}

variable "kms_key_id_arn" {
  description = "The ARN of the KMS key for server-side encryption."
  type        = string
}

variable "locale" {
  description = "KnowledgeBase locale Key"
  type        = string
}

variable "region" {
  description = "The AWS region where resources will be created."
  type        = string
}
