
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


