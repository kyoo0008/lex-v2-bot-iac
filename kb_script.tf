
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
