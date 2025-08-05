# Amazon Q in Connect 유지보수를 위한 Terraform 예시 파일

# AWS 공급자 설정
provider "awscc" {
  region = "ap-northeast-2" # 원하는 리전으로 변경
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
    key   = "Name"
    value = "example-assistant"
  }]
}



# # -----------------------------------------------------------------------------
# # 기술 자료 생성
# # -----------------------------------------------------------------------------
resource "awscc_wisdom_knowledge_base" "example" {
  name                = "example-knowledge-base"
  knowledge_base_type = "CUSTOM"
  description         = "Example knowledge base for Amazon Q in Connect"

  vector_ingestion_configuration = {
    chunking_configuration = {
      chunking_strategy = "SEMANTIC"
      semantic_chunking_configuration = {
        breakpoint_percentile_threshold = 90
        buffer_size                     = 0.8
        max_tokens                      = 1000
      }
    }
  }

  server_side_encryption_configuration = {
    kms_key_id = awscc_kms_key.example.arn
  }


  # source_configuration = {

  #   app_integrations = {
  #     app_integration_arn = awscc_appintegrations_data_integration.example.data_integration_arn

  #     # object_fields = [""]
  #   }
  # }

  tags = [{
    key   = "Name"
    value = "example-knowledge-base"
  }]

  depends_on = [
    awscc_appintegrations_data_integration.example
  ]
}

# # -----------------------------------------------------------------------------
# # Assistant와 기술 자료 연결
# # -----------------------------------------------------------------------------
resource "awscc_wisdom_assistant_association" "example" {
  assistant_id      = awscc_wisdom_assistant.example.id
  association_type  = "KNOWLEDGE_BASE"
  association = {
    knowledge_base_id = awscc_wisdom_knowledge_base.example.id
  }

  tags = [{
    key   = "Name"
    value = "example-association"
  }]

  depends_on = [
    awscc_wisdom_knowledge_base.example
  ]
}



resource "awscc_appintegrations_data_integration" "example" {
  name = "example_integ"
  source_uri = "s3://amazon-q-connect-aicc-test-bucket"
  kms_key = awscc_kms_key.example.arn
}

# resource "awscc_connect_integration_association" "wisdom_assistant" {
#   instance_id      = data.aws_connect_instance.connect_instance.arn
#   integration_arn  = awscc_wisdom_assistant.example.assistant_arn
#   integration_type = "WISDOM_ASSISTANT"
# }

# resource "awscc_connect_integration_association" "wisdom_knowledge_base" {
#   instance_id      = data.aws_connect_instance.connect_instance.arn
#   integration_arn  = awscc_wisdom_knowledge_base.example.knowledge_base_arn
#   integration_type = "WISDOM_KNOWLEDGE_BASE"
# }


