
# -----------------------------------------------------------------------------
# association delete, create 로직
# -----------------------------------------------------------------------------
resource "terraform_data" "association_manager" {
  triggers_replace = [
    awscc_wisdom_assistant.example,
    awscc_wisdom_knowledge_base.example,
    data.aws_connect_instance.connect_instance.id
  ]

  # Assistant 연결 삭제
  provisioner "local-exec" {
    command = <<EOT
CONNECT_INSTANCE_ID="${data.aws_connect_instance.connect_instance.id}"
NEW_ASSISTANT_ASSOCIATION_ARN="${awscc_wisdom_assistant.example.assistant_arn}"

ASSISTANT_ASSOCIATIONS_JSON=$(aws connect list-integration-associations \
--instance-id "$CONNECT_INSTANCE_ID" \
--query "IntegrationAssociationSummaryList[?IntegrationType=='WISDOM_ASSISTANT']" \
--output json)

if [ "$(echo "$ASSISTANT_ASSOCIATIONS_JSON" | jq 'length')" -gt 0 ]; then
  echo "$ASSISTANT_ASSOCIATIONS_JSON" | jq -r '.[].IntegrationAssociationId' | while read -r ASSOCIATION_ID; do
    echo "Deleting Assistant association: $ASSOCIATION_ID"
    aws connect delete-integration-association \
      --instance-id "$CONNECT_INSTANCE_ID" \
      --integration-association-id "$ASSOCIATION_ID"
    sleep 1
  done
else
  echo "Assistant association not found, skipping deletion."
fi

echo "Creating Assistant association: $NEW_ASSISTANT_ASSOCIATION_ARN"
aws connect create-integration-association \
  --instance-id "$CONNECT_INSTANCE_ID" \
  --integration-type "WISDOM_ASSISTANT" \
  --integration-arn "$NEW_ASSISTANT_ASSOCIATION_ARN"
EOT
  }

  # Knowledge Base 연결 삭제
  provisioner "local-exec" {
    command = <<EOT
CONNECT_INSTANCE_ID="${data.aws_connect_instance.connect_instance.id}"
NEW_KB_ASSOCIATION_ARN="${awscc_wisdom_knowledge_base.example.knowledge_base_arn}"

KB_ASSOCIATIONS_JSON=$(aws connect list-integration-associations \
--instance-id "$CONNECT_INSTANCE_ID" \
--query "IntegrationAssociationSummaryList[?IntegrationType=='WISDOM_KNOWLEDGE_BASE']" \
--output json)

if [ "$(echo "$KB_ASSOCIATIONS_JSON" | jq 'length')" -gt 0 ]; then
  echo "$KB_ASSOCIATIONS_JSON" | jq -r '.[].IntegrationAssociationId' | while read -r ASSOCIATION_ID; do
    echo "Deleting Knowledge Base association: $ASSOCIATION_ID"
    aws connect delete-integration-association \
      --instance-id "$CONNECT_INSTANCE_ID" \
      --integration-association-id "$ASSOCIATION_ID"
    sleep 1
  done
else
  echo "Knowledge Base association not found, skipping deletion."
fi

echo "Creating Knowledge Base association: $NEW_KB_ASSOCIATION_ARN"
aws connect create-integration-association \
  --instance-id "$CONNECT_INSTANCE_ID" \
  --integration-type "WISDOM_KNOWLEDGE_BASE" \
  --integration-arn "$NEW_KB_ASSOCIATION_ARN"
EOT
  }
}

resource "terraform_data" "wisdom_ai_prompt_manager" {

  triggers_replace = [
    awscc_wisdom_assistant.example,
    local.prompt_name,
    local.prompt_model_id,
    filemd5(data.local_file.prompt_txt.filename)
  ]

  provisioner "local-exec" {
    command = <<EOT

AI_PROMPT_JSON=$(aws qconnect list-ai-prompts \
--assistant-id "${awscc_wisdom_assistant.example.assistant_id}" \
--query "aiPromptSummaries[?name=='${local.prompt_name}']" \
--output json)

if [ "$(echo "$AI_PROMPT_JSON" | jq 'length')" -gt 0 ]; then
  echo "$AI_PROMPT_JSON" | jq -r '.[].aiPromptId' | while read -r AI_PROMPT_ID; do
    echo "Deleting AI Prompt: $AI_PROMPT_ID"
    aws qconnect delete-ai-prompt \
      --assistant-id "${awscc_wisdom_assistant.example.assistant_id}" \
      --ai-prompt-id "$AI_PROMPT_ID"
    sleep 1
  done
else
  echo "AI Prompt not found, skipping deletion."
fi

GIT_ROOT_PATH=$(git rev-parse --show-toplevel)

PROMPT_CONTENT=$(cat $GIT_ROOT_PATH/prompt.txt)

jq -n \
  --arg assistantId "${awscc_wisdom_assistant.example.assistant_id}" \
  --arg promptName "${local.prompt_name}" \
  --arg promptContent "$PROMPT_CONTENT" \
  '{
    "assistantId": $assistantId,
    "name": $promptName,
    "apiFormat": "TEXT_COMPLETIONS",
    "modelId": "${local.prompt_model_id}",
    "templateType": "TEXT",
    "type": "ANSWER_GENERATION",
    "visibilityStatus": "PUBLISHED",
    "templateConfiguration": {
      "textFullAIPromptEditTemplateConfiguration": {
        "text": $promptContent
      }
    }
  }' > qconnect-prompt-input.json

aws qconnect create-ai-prompt \
  --region ${var.region} \
  --cli-input-json file://qconnect-prompt-input.json | jq .
EOT
  }
}
