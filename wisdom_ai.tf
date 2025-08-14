# -----------------------------------------------------------------------------
# Manage AI Agent -> 이후 update-assistant-ai-agent
# -----------------------------------------------------------------------------
resource "terraform_data" "wisdom_ai_agent_manager" {

  triggers_replace = [
    awscc_wisdom_assistant.example,
    local.agent_name,local.locale,local.agent_type,
    data.external.wisdom_ai_prompt.result
  ]

  input = {
    assistant_id   = awscc_wisdom_assistant.example.assistant_id
    agent_name    = local.agent_name
    prompt_id       = data.external.wisdom_ai_prompt.result.ai_prompt_id
    region         = var.region
    locale         = local.locale
    agent_type     = local.agent_type
  }

  provisioner "local-exec" {
    command = "chmod +x ${path.module}/scripts/manage_ai_agent.sh && ${path.module}/scripts/manage_ai_agent.sh upsert"
    
    # 스크립트에 환경 변수로 값 전달
    environment = {
      ASSISTANT_ID   = self.input.assistant_id
      AGENT_NAME    = self.input.agent_name
      REGION         = self.input.region
      PROMPT_ID      = self.input.prompt_id
      LOCALE        = self.input.locale
      AGENT_TYPE    = self.input.agent_type
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "chmod +x ${path.module}/scripts/manage_ai_agent.sh && ${path.module}/scripts/manage_ai_agent.sh delete"
    
    environment = {
      ASSISTANT_ID   = self.input.assistant_id
      AGENT_NAME    = self.input.agent_name
      REGION         = self.input.region
      PROMPT_ID      = self.input.prompt_id
      LOCALE        = self.input.locale
      AGENT_TYPE    = self.input.agent_type
    }
  }
}

data "external" "wisdom_ai_agent" {
  program = ["/bin/bash", "-c", <<-EOT
    aws qconnect list-ai-agents \
      --assistant-id "${awscc_wisdom_assistant.example.assistant_id}" \
      | jq '
          ( .aiAgentSummaries | map(select(.name == "${local.agent_name}")) | .[0] )
          // {}
          | {
              "ai_agent_id": .aiAgentId,
              "ai_agent_arn": .aiAgentArn,
              "name": .name
            }
        '
  EOT
  ]
}



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
    model_id       = local.prompt_model_id
    region         = var.region
    prompt_content = file("${path.module}/prompts/prompt.txt")
    prompt_name    = local.prompt_name
  }

  provisioner "local-exec" {
    command = "chmod +x ${path.module}/scripts/manage_ai_prompt.sh && ${path.module}/scripts/manage_ai_prompt.sh create"
    
    # 스크립트에 환경 변수로 값 전달
    environment = {
      ASSISTANT_ID   = self.input.assistant_id
      MODEL_ID       = self.input.model_id
      REGION         = self.input.region
      PROMPT_CONTENT = self.input.prompt_content
      PROMPT_NAME    = self.input.prompt_name
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "chmod +x ${path.module}/scripts/manage_ai_prompt.sh && ${path.module}/scripts/manage_ai_prompt.sh delete"
    
    environment = {
      ASSISTANT_ID   = self.input.assistant_id
      MODEL_ID       = self.input.model_id
      REGION         = self.input.region
      PROMPT_CONTENT = self.input.prompt_content
      PROMPT_NAME    = self.input.prompt_name
    }
  }
}


data "external" "wisdom_ai_prompt" {
  program = ["/bin/bash", "-c", <<-EOT
    aws qconnect list-ai-prompts \
      --assistant-id "${awscc_wisdom_assistant.example.assistant_id}" \
      | jq '
          ( .aiPromptSummaries | map(select(.name == "${local.prompt_name}")) | .[0] )
          // {}
          | { 
              "ai_prompt_id": .aiPromptId, 
              "ai_prompt_arn": .aiPromptArn, 
              "name": .name 
            }
          '
  EOT
  ]
}






# # ISSUE : "visibilityStatus": "PUBLISHED" 옵션이 현재 없어서 awscc_wisdom_ai(agent, prompt, guardrail)로 update 하지 못함 
# -----------------------------------------------------------------------------
# Manage AI Agent
# -----------------------------------------------------------------------------
# resource "awscc_wisdom_ai_agent" "example" {
#   assistant_id = awscc_wisdom_assistant.example.id
#   type         = "ANSWER_RECOMMENDATION"
#   description  = "Example AI agent for Amazon Q in Connect"

#   configuration = {
#     answer_recommendation_ai_agent_configuration = {
#       answer_generation_ai_prompt_id = awscc_wisdom_ai_prompt.example.id
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