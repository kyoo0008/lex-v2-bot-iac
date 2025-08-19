#!/bin/bash
set -e # 스크립트 실행 중 오류가 발생하면 즉시 중단

# --- 입력 파라미터 ---
ACTION="$1"

# 환경 변수에서 Terraform 값들을 가져옵니다.
if [ -z "$CONNECT_INSTANCE_ID" ] || [ -z "$ASSISTANT_ARN" ] || [ -z "$KB_NAME" ]; then
  echo "Error: environment variable is not set."
  exit 1
fi

ASSISTANT_ID=$(echo "$ASSISTANT_ARN" | awk -F'/' '{print $NF}')
KB_ARN=$(aws qconnect list-knowledge-bases --query "knowledgeBaseSummaries[?name=='$KB_NAME']" | jq -r '.[0].knowledgeBaseArn')
KB_ID=$(echo "$KB_ARN" | awk -F'/' '{print $NF}')
# --- 공통 함수: 특정 타입의 연결을 모두 삭제 ---
# $1: 삭제할 IntegrationType (예: WISDOM_ASSISTANT)
delete_connect_associations_by_type() {
  local INTEGRATION_TYPE="$1" # 함수 내 지역 변수로 선언

  echo "Searching for Amazon Connect instance associations of type: $INTEGRATION_TYPE"
  
  ASSOCIATIONS_JSON=$(aws connect list-integration-associations \
    --instance-id "$CONNECT_INSTANCE_ID" \
    --query "IntegrationAssociationSummaryList[?IntegrationType=='$INTEGRATION_TYPE']" \
    --output json)

  if [ "$(echo "$ASSOCIATIONS_JSON" | jq 'length')" -gt 0 ]; then
    echo "$ASSOCIATIONS_JSON" | jq -r '.[].IntegrationAssociationId' | while read -r ASSOCIATION_ID; do
      echo "Deleting association ID: $ASSOCIATION_ID (Type: $INTEGRATION_TYPE)"
      aws connect delete-integration-association \
        --instance-id "$CONNECT_INSTANCE_ID" \
        --integration-association-id "$ASSOCIATION_ID"
      sleep 1
    done
  else
    echo "Association type '$INTEGRATION_TYPE' not found, skipping deletion."
  fi

}


delete_assistant_associations() {

  echo "Searching for Amazon Q Connect Assistant associations for Assistant Arn : $ASSISTANT_ARN"
  
  ASSISTANT_ASSOCIATIONS_JSON=$(aws qconnect list-assistant-associations \
    --query "assistantAssociationSummaries[?assistantArn=='$ASSISTANT_ARN']" \
    --output json)


  if [ "$(echo "$ASSISTANT_ASSOCIATIONS_JSON" | jq 'length')" -gt 0 ] || [ -z "$ASSISTANT_ID" ]; then
    echo "$ASSISTANT_ASSOCIATIONS_JSON" | jq -r '.[].assistantAssociationId' | while read -r ASSISTANT_ASSOCIATION_ID; do
      echo "Deleting assistant association ID: $ASSISTANT_ASSOCIATION_ID"
      aws qconnect delete-assistant-association \
        --assistant-association-id $ASSISTANT_ASSOCIATION_ID \
        --assistant-id $ASSISTANT_ID
      sleep 1
    done
  else
    echo "Association assistant arn '$ASSISTANT_ARN' not found, skipping deletion."
  fi

}



# --- 공통 함수: 특정 타입의 연결을 생성 ---
# $1: 생성할 IntegrationType
# $2: 연결할 IntegrationArn
create_connect_association() {
  local INTEGRATION_TYPE="$1"
  local INTEGRATION_ARN="$2"

  if [ -z "$INTEGRATION_ARN" ]; then
    echo "Warning: ARN for $INTEGRATION_TYPE is empty, skipping creation."
    return
  fi

  echo "Creating association for type: $INTEGRATION_TYPE"
  aws connect create-integration-association \
    --instance-id "$CONNECT_INSTANCE_ID" \
    --integration-type "$INTEGRATION_TYPE" \
    --integration-arn "$INTEGRATION_ARN"
}

create_assistant_associations() {

  echo "Creating association for assistant($ASSISTANT_ID) and kb($KB_ID) "
  aws qconnect create-assistant-association \
    --assistant-id "$ASSISTANT_ID" \
    --association-type "KNOWLEDGE_BASE" \
    --association "{\"knowledgeBaseId\": \"$KB_ID\"}" 
}

# --- 메인 로직 ---
case "$ACTION" in
  # 생성/업데이트 시: 기존 연결 모두 삭제 후 새로 생성
  create)
    echo "Performing 'create' (replace) action for all associations."
    delete_connect_associations_by_type "WISDOM_ASSISTANT"
    delete_connect_associations_by_type "WISDOM_KNOWLEDGE_BASE"
    delete_assistant_associations
    create_assistant_associations
    create_connect_association "WISDOM_ASSISTANT" "$ASSISTANT_ARN"
    create_connect_association "WISDOM_KNOWLEDGE_BASE" "$KB_ARN"
    ;;

  # 삭제 시: 기존 연결 모두 삭제
  delete)
    echo "Performing 'delete' action for all associations."
    delete_assistant_associations
    delete_connect_associations_by_type "WISDOM_ASSISTANT"
    delete_connect_associations_by_type "WISDOM_KNOWLEDGE_BASE"
    ;;

  *)
    echo "Error: Invalid action '$ACTION'. Use 'create' or 'delete'."
    exit 1
    ;;
esac

echo "Action '$ACTION' completed successfully."
