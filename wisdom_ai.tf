# # ISSUE : "visibilityStatus": "PUBLISHED" 옵션이 현재 없어서 awscc_wisdom_ai(agent, prompt, guardrail)로 update 하지 못함 
# # -----------------------------------------------------------------------------
# # Manage AI Agent -> 이후 update-assistant-ai-agent
# # -----------------------------------------------------------------------------
# resource "terraform_data" "wisdom_ai_agent_manager" {

#   triggers_replace = [
#     awscc_wisdom_assistant.example,
#     local.agent_name,local.locale,local.agent_type,
#     data.external.wisdom_ai_prompt.result
#   ]

#   input = {
#     assistant_id   = awscc_wisdom_assistant.example.assistant_id
#     agent_name    = local.agent_name
#     prompt_id       = data.external.wisdom_ai_prompt.result.ai_prompt_id
#     region         = var.region
#     locale         = local.locale
#     agent_type     = local.agent_type
#   }

#   provisioner "local-exec" {
#     command = "chmod +x ${path.module}/scripts/manage_ai_agent.sh && ${path.module}/scripts/manage_ai_agent.sh upsert"
    
#     # 스크립트에 환경 변수로 값 전달
#     environment = {
#       ASSISTANT_ID   = self.input.assistant_id
#       AGENT_NAME    = self.input.agent_name
#       REGION         = self.input.region
#       PROMPT_ID      = self.input.prompt_id
#       LOCALE        = self.input.locale
#       AGENT_TYPE    = self.input.agent_type
#     }
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = "chmod +x ${path.module}/scripts/manage_ai_agent.sh && ${path.module}/scripts/manage_ai_agent.sh delete"
    
#     environment = {
#       ASSISTANT_ID   = self.input.assistant_id
#       AGENT_NAME    = self.input.agent_name
#       REGION         = self.input.region
#       PROMPT_ID      = self.input.prompt_id
#       LOCALE        = self.input.locale
#       AGENT_TYPE    = self.input.agent_type
#     }
#   }
# }

# data "external" "wisdom_ai_agent" {
#   program = ["/bin/bash", "-c", <<-EOT
#     aws qconnect list-ai-agents \
#       --assistant-id "${awscc_wisdom_assistant.example.assistant_id}" \
#       | jq '
#           ( .aiAgentSummaries | map(select(.name == "${local.agent_name}")) | .[0] )
#           // {}
#           | {
#               "ai_agent_id": .aiAgentId,
#               "ai_agent_arn": .aiAgentArn,
#               "name": .name
#             }
#         '
#   EOT
#   ]
# }



# # -----------------------------------------------------------------------------
# # Manage AI Prompt 
# # -----------------------------------------------------------------------------
resource "terraform_data" "ai_prompt_answer_generation_manager" {

  triggers_replace = [
    awscc_wisdom_assistant.example,
    local.answer_generation_prompt_name,
    local.prompt_model_id,
    filemd5(data.local_file.answer_generation_prompt_txt.filename),
    filemd5("${path.module}/scripts/manage_ai_prompt.sh")
  ]

  input = {
    assistant_id   = awscc_wisdom_assistant.example.assistant_id
    model_id       = local.prompt_model_id
    region         = var.region
    prompt_content = file(data.local_file.answer_generation_prompt_txt.filename)
    prompt_name    = local.answer_generation_prompt_name
    prompt_type    = "ANSWER_GENERATION"
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
      PROMPT_TYPE    = self.input.prompt_type
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
      PROMPT_TYPE    = self.input.prompt_type
    }
  }

  depends_on = [
    awscc_wisdom_assistant.example
  ]
}



resource "terraform_data" "ai_prompt_query_reformulation_manager" {

  triggers_replace = [
    awscc_wisdom_assistant.example,
    local.query_reformulation_prompt_name,
    local.prompt_model_id,
    filemd5(data.local_file.query_reformulation_prompt_txt.filename),
    filemd5("${path.module}/scripts/manage_ai_prompt.sh")
  ]

  input = {
    assistant_id   = awscc_wisdom_assistant.example.assistant_id
    model_id       = local.prompt_model_id
    region         = var.region
    prompt_content = file(data.local_file.query_reformulation_prompt_txt.filename)
    prompt_name    = local.query_reformulation_prompt_name
    prompt_type    = "QUERY_REFORMULATION"
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
      PROMPT_TYPE    = self.input.prompt_type
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
      PROMPT_TYPE    = self.input.prompt_type
    }
  }

  depends_on = [
    awscc_wisdom_assistant.example
  ]
}


# data "external" "wisdom_ai_prompt" {
#   program = ["/bin/bash", "-c", <<-EOT
#     aws qconnect list-ai-prompts \
#       --assistant-id "${awscc_wisdom_assistant.example.assistant_id}" \
#       | jq '
#           ( .aiPromptSummaries | map(select(.name == "${local.prompt_name}")) | .[0] )
#           // {}
#           | { 
#               "ai_prompt_id": .aiPromptId, 
#               "ai_prompt_arn": .aiPromptArn, 
#               "name": .name 
#             }
#           '
#   EOT
#   ]
# }







