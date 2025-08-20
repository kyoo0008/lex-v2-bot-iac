# Amazon Q in Connect 유지보수를 위한 Terraform 예시 파일

# AWS 공급자 설정
provider "awscc" {
  region = "${var.region}" # 원하는 리전으로 변경
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# KMS 키 생성 (암호화용)
# -----------------------------------------------------------------------------
resource "awscc_kms_key" "example" {
  description = "Example KMS key for Amazon Q in Connect"
  enabled     = true
  key_policy  = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Effect = "Allow",
        Principal = {
            Service = "connect.amazonaws.com"
        },
        Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
        ],
        Resource = "*"
    }
    ]
  })
}

# -----------------------------------------------------------------------------
# Assistant 생성(=Amazon Q Domain)
# -----------------------------------------------------------------------------
resource "awscc_wisdom_assistant" "example" {
  name = "example-assistant"
  type = "AGENT"
  description = "Example assistant for Amazon Q in Connect"

  server_side_encryption_configuration = {
    kms_key_id = awscc_kms_key.example.arn
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



