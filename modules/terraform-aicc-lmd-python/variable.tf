# Copyright © Amazon.com and Affiliates: This deliverable is considered Developed Content as defined in the AWS Service Terms and the SOW between the parties dated [March 18, 2024].

# -------------------------------------------------------------------------------------------------
# // Identity
# -------------------------------------------------------------------------------------------------
variable "application" {
  description = "First prefix of all resource names"
  type        = string
  default     = "aicc"
}

variable "env" {
  description = "Environment name - dev/stg/prd"
  type        = string
}

variable "boundary" {
  description = "Boundary of all resource names"
  type        = string
}

variable "func_name" {
  description = "Lambda function name"
  type        = string
}

variable "func_description" {
  description = "Lambda function description"
  type        = string
  default     = null
}

variable "func_tracing_mode" {
  description = "Lambda function X-Ray tracing option"
  type        = string
  default     = "PassThrough" // PassThrough, Active

  validation {
    condition     = can(regex("(PassThrough|Active)", var.func_tracing_mode))
    error_message = "Valid values are 'PassThrough' and 'Active'"
  }
}

# -------------------------------------------------------------------------------------------------
# // Lambda function runtime
# -------------------------------------------------------------------------------------------------
variable "func_architecture" {
  description = "Lambda function architecture"
  type        = list(string)
  default     = ["x86_64"]
}

variable "func_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "nodejs20.x"
}

variable "func_source_path" {
  description = "Lambda function source file(.zip) path - if it's served, terraform control to upload package file(.zip)"
  type        = string
  default     = null // Only upload initial function zip file once, then will be controlled by application's pipeline after terraform provision

  validation {
    condition     = var.func_source_path != null
    error_message = "The func_source_path value must not be null"
  }
}

variable "func_source_zip_path" {
  description = "Lambda function source file(.zip) path - if it's served, terraform control to upload package file(.zip)"
  type        = string
  default     = null // Only upload initial function zip file once, then will be controlled by application's pipeline after terraform provision

  validation {
    condition     = var.func_source_zip_path != null || can(regex("\\.zip$", var.func_source_zip_path))
    error_message = "The func_source_zip_path value must be null or string end with '.zip'"
  }
}

variable "func_source_hash" {
  description = "Lambda function source hash - if it's served, it must be set to a base64-encoded SHA256 hash of the package(Zip) file"
  type        = string
  default     = null // Only upload initial function zip file once, then will be controlled by application's pipeline after terraform provision
}

variable "func_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "app.handler"
}

variable "func_timeout" {
  description = "Lambda function timeout"
  type        = number
  default     = 5
}

variable "func_memory_size_mb" {
  description = "Lambda function memory size (MB)"
  type        = number
  default     = 512
}

variable "func_storage_size_mb" {
  description = "Lambda function storage size (MB)"
  type        = number
  default     = 512
}

variable "func_environment_variables" {
  description = "Lambda function environment variables"
  type        = map(string)
  default = {
    POWERTOOLS_LOG_LEVEL = "INFO"
  }
}

# -------------------------------------------------------------------------------------------------
# // Lambda function permision
# -------------------------------------------------------------------------------------------------
variable "func_inline_policy_json" {
  description = "Lambda function inline policy"
  type = object({
    Version = string
    Statement = list(object({
      Sid      = string
      Effect   = string
      Action   = list(string)
      Resource = list(string)

      # Condition block
      Condition = optional(map(map(list(string))))
    }))
  })
  default = null
}

# -------------------------------------------------------------------------------------------------
# // Lambda function layer
# -------------------------------------------------------------------------------------------------
variable "func_layer" {
  description = "Lambda Layer for pandas"
  type        = list(any)
  default     = []
}
