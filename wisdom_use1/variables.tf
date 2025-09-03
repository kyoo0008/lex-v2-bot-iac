variable "region" {
  description = "배포할 AWS 리전"
  type        = string
  default     = "us-east-1"
}

variable "region_code" {
  description = "배포할 AWS 리전(code)"
  type        = string
  default     = "ue1"
}

variable "project_root_path" {
  description = "Terraform 프로젝트의 루트 경로"
  type        = string
  default     = "./"
}

variable "connect_instance_alias" {
  description = "Amazon Connect instance alias"
  type        = string
  default     = "kal-servicecenter-use1-dev"
}


variable "application" {
  default = "aicc"
}

variable "env" {
  default = "dev"
}