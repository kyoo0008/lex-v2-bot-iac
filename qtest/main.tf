# Amazon Q in Connect 유지보수를 위한 Terraform 예시 파일
locals {
  kb_name = "qic-kb-test"
}

variable "region" {
  default = "ap-northeast-2"
}

variable "connect_instance_alias" {
  description = "Amazon Connect instance alias"
  type        = string
  default     = "ivr-aicc-test-b"
}

data "aws_connect_instance" "connect_instance" {
  instance_alias = var.connect_instance_alias
}



# AWS 공급자 설정
provider "awscc" {
  region = "${var.region}" # 원하는 리전으로 변경
}



data "aws_caller_identity" "current" {}

data "aws_kms_key" "example" {
  key_id = "alias/amazon-q-in-connect-key"
}

# -----------------------------------------------------------------------------
# KMS 키 생성 (암호화용)
# -----------------------------------------------------------------------------
# resource "awscc_kms_key" "example" {
#   description = "Example KMS key for Amazon Q in Connect"
#   enabled     = true
#   key_policy  = jsonencode({
#     Version   = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "Enable IAM User Permissions"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
#         }
#         Action   = "kms:*"
#         Resource = "*"
#       },
#       {
#         Effect = "Allow",
#         Principal = {
#             Service = "connect.amazonaws.com"
#         },
#         Action = [
#             "kms:Decrypt",
#             "kms:GenerateDataKey*",
#             "kms:DescribeKey"
#         ],
#         Resource = "*"
#     }
#     ]
#   })
# }



# -----------------------------------------------------------------------------
# Assistant 생성(=Amazon Q Domain)
# -----------------------------------------------------------------------------
resource "awscc_wisdom_assistant" "example" {
  name = "example-assistant"
  type = "AGENT"
  description = "Example assistant for Amazon Q in Connect"

  server_side_encryption_configuration = {
    kms_key_id = data.aws_kms_key.example.arn
  }

  tags = [{
    key   = "AmazonConnectEnabled"
    value = "True"
  }]

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}



# # -----------------------------------------------------------------------------
# # 기술 자료 생성
# # -----------------------------------------------------------------------------
resource "awscc_wisdom_knowledge_base" "example" {
  name                = local.kb_name
  knowledge_base_type = "CUSTOM"
  description         = "Example knowledge base for Amazon Q in Connect"

  server_side_encryption_configuration = {
    kms_key_id = data.aws_kms_key.example.arn
  }

  source_configuration = {

    app_integrations = {
      app_integration_arn = awscc_appintegrations_data_integration.example.data_integration_arn

      # object_fields = ["content"]
    }
  }

  tags = [{
    key   = "AmazonConnectEnabled"
    value = "True"
  }]

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }

  depends_on = [
    awscc_appintegrations_data_integration.example
  ]
}

resource "awscc_appintegrations_data_integration" "example" {
  name = "${local.kb_name}"
  source_uri = "s3://${aws_s3_bucket.qic_kb_bucket.bucket}"
  kms_key = data.aws_kms_key.example.arn

  depends_on = [
    aws_s3_object.folder_upload
  ]
}


resource "aws_s3_bucket" "qic_kb_bucket" {
  bucket = "qic-kb-bucket-test"
  force_destroy = false
}



# # -----------------------------------------------------------------------------
# # Assistant와 기술 자료 연결
# # -----------------------------------------------------------------------------
resource "awscc_wisdom_assistant_association" "example" {
  assistant_id      = awscc_wisdom_assistant.example.id
  association_type  = "KNOWLEDGE_BASE" # type은 이것 밖에 지원 안함 
  association = {
    knowledge_base_id = awscc_wisdom_knowledge_base.example.id
  }

  tags = [{
    key   = "AmazonConnectEnabled"
    value = "True"
  }]

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }

  depends_on = [
    awscc_wisdom_knowledge_base.example
  ]
}



resource "aws_s3_object" "folder_upload" {
  # for_each = fileset("${path.module}/QiCContent", "**/*")
  for_each = {
    for file in fileset("${path.module}/QiCContent", "**/*") : file => file
    if !can(regex(".*\\.DS_Store$", file)) # Example: ignore files ending with .ignore
  }


  bucket = aws_s3_bucket.qic_kb_bucket.id
  key    = each.value
  source = "${path.module}/QiCContent/${each.value}"

  source_hash = filemd5("${path.module}/QiCContent/${each.value}")

  # lifecycle {
  #   ignore_changes = [
  #     tags
  #   ]
  # }
}

