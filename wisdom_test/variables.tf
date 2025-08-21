variable "region" {
  description = "배포할 AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_root_path" {
  description = "Terraform 프로젝트의 루트 경로"
  type        = string
  default     = "./"
}

variable "connect_instance_alias" {
  description = "Amazon Connect instance alias"
  type        = string
  default     = "ivr-aicc-test-b"
}


