# Amazon Q in Connect 유지보수를 위한 Terraform 예시 파일

# AWS 공급자 설정
provider "awscc" {
  region = "ap-northeast-2" # 원하는 리전으로 변경
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

data "aws_caller_identity" "current" {}
# # -----------------------------------------------------------------------------
# # 기술 자료 생성
# # -----------------------------------------------------------------------------
# resource "awscc_wisdom_knowledge_base" "example" {
#   name                = "example-knowledge-base"
#   knowledge_base_type = "CUSTOM"
#   description         = "Example knowledge base for Amazon Q in Connect"

#   vector_ingestion_configuration = {
#     chunking_configuration = {
#       chunking_strategy = "SEMANTIC"
#       semantic_chunking_configuration = {
#         breakpoint_percentile_threshold = 90
#         buffer_size                     = 0.8
#         max_tokens                      = 1000
#       }
#     }
#   }

#   tags = [{
#     key   = "Name"
#     value = "example-knowledge-base"
#   }]
# }

# # -----------------------------------------------------------------------------
# # Assistant와 기술 자료 연결
# # -----------------------------------------------------------------------------
# resource "awscc_wisdom_assistant_association" "example" {
#   assistant_id      = awscc_wisdom_assistant.example.id
#   association_type  = "KNOWLEDGE_BASE"
#   association = {
#     knowledge_base_id = awscc_wisdom_knowledge_base.example.id
#   }

#   tags = [{
#     key   = "Name"
#     value = "example-association"
#   }]
# }

# # -----------------------------------------------------------------------------
# # AI 에이전트 생성
# # -----------------------------------------------------------------------------
# resource "awscc_wisdom_ai_agent" "example" {
#   assistant_id = awscc_wisdom_assistant.example.id
#   type         = "ANSWER_RECOMMENDATION"
#   description  = "Example AI agent for Amazon Q in Connect"

#   configuration = {
#     answer_recommendation_ai_agent_configuration = {
#       answer_generation_ai_prompt_id = awscc_wisdom_ai_prompt.example.id
#       answer_generation_ai_guardrail_id = awscc_wisdom_ai_guardrail.example.id
#       locale = "en_US"
#     }
#   }

#   tags = {
#     Name = "example-ai-agent"
#   }
# }

# # -----------------------------------------------------------------------------
# # AI 프롬프트 생성
# # -----------------------------------------------------------------------------
# resource "awscc_wisdom_ai_prompt" "example" {
#   assistant_id = awscc_wisdom_assistant.example.id
#   name         = "example-ai-prompt"
#   description  = "Example AI prompt for Amazon Q in Connect"
#   type         = "ANSWER_GENERATION"
#   api_format   = "ANTHROPIC_CLAUDE_TEXT_COMPLETIONS"
#   model_id     = "anthropic.claude-v2"
#   template_type = "TEXT"
#   template_configuration = {
#     text_full_ai_prompt_edit_template_configuration = {
#       text = "Based on the provided context, answer the user's question."
#     }
#   }

#   tags = {
#     Name = "example-ai-prompt"
#   }
# }

# # -----------------------------------------------------------------------------
# # AI 가드레일 생성
# # -----------------------------------------------------------------------------
# resource "awscc_wisdom_ai_guardrail" "example" {
#   name                = "example-ai-guardrail"
#   assistant_id        = awscc_wisdom_assistant.example.id
#   blocked_input_messaging  = "I'm sorry, I can't answer that."
#   blocked_outputs_messaging = "I'm sorry, I can't provide that information."

#   content_policy_config = {
#     filters_config = [
#       {
#         type          = "HATE"
#         input_strength  = "HIGH"
#         output_strength = "HIGH"
#       }
#     ]
#   }

#   tags = {
#     Name = "example-ai-guardrail"
#   }
# }

