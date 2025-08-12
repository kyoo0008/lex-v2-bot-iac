# # ISSUE : "visibilityStatus": "PUBLISHED" 옵션이 현재 없어서 awscc_wisdom_ai_prompt(agent, guardrail)로 update 하지 못함 
# -----------------------------------------------------------------------------
# Manage AI Agent
# -----------------------------------------------------------------------------
# resource "awscc_wisdom_ai_agent" "example" {
#   assistant_id = awscc_wisdom_assistant.example.id
#   type         = "ANSWER_RECOMMENDATION"
#   description  = "Example AI agent for Amazon Q in Connect"

#   configuration = {
#     answer_recommendation_ai_agent_configuration = {
#       answer_generation_ai_prompt_id = data.external.wisdom_ai_prompt.result.ai_prompt_id
#       # answer_generation_ai_guardrail_id = awscc_wisdom_ai_guardrail.example.id
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


# -----------------------------------------------------------------------------
# Manage AI Prompt 
# -----------------------------------------------------------------------------

resource "terraform_data" "wisdom_ai_prompt_manager" {

  triggers_replace = [
    awscc_wisdom_assistant.example,
    local.prompt_name,
    local.prompt_model_id,
    filemd5(data.local_file.prompt_txt.filename)
  ]

  input = {
    assistant_id   = awscc_wisdom_assistant.example.assistant_id
    prompt_name    = local.prompt_name
    model_id       = local.prompt_model_id
    region         = var.region
    prompt_content = file("${path.module}/prompts/prompt.txt")
  }

  provisioner "local-exec" {
    command = "chmod +x ${path.module}/scripts/manage_ai_prompt.sh && ${path.module}/scripts/manage_ai_prompt.sh create"
    
    # 스크립트에 환경 변수로 값 전달
    environment = {
      ASSISTANT_ID   = self.input.assistant_id
      PROMPT_NAME    = self.input.prompt_name
      MODEL_ID       = self.input.model_id
      REGION         = self.input.region
      PROMPT_CONTENT = self.input.prompt_content
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "chmod +x ${path.module}/scripts/manage_ai_prompt.sh && ${path.module}/scripts/manage_ai_prompt.sh delete"
    
    environment = {
      ASSISTANT_ID   = self.input.assistant_id
      PROMPT_NAME    = self.input.prompt_name
      MODEL_ID       = self.input.model_id
      REGION         = self.input.region
      PROMPT_CONTENT = self.input.prompt_content
    }
  }
}


data "external" "wisdom_ai_prompt" {
  program = ["/bin/bash", "-c", <<-EOT
    aws qconnect list-ai-prompts \
      --assistant-id "${awscc_wisdom_assistant.example.assistant_id}" \
      | jq '.aiPromptSummaries[] | select(.name == "${local.prompt_name}")' \
      | jq '{ "ai_prompt_id": .aiPromptId, "ai_prompt_arn": .aiPromptArn, "name": .name }'
  EOT
  ]
}


