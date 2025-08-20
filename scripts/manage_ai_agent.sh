#!/bin/bash
set -e # 스크립트 실행 중 오류가 발생하면 즉시 중단

# --- 입력 파라미터 ---
ACTION="$1"

# 환경 변수에서 Terraform 값들을 가져옵니다.
# ASSISTANT_ID, AGENT_NAME, PROMPT_NAME, REGION, AGENT_TYPE, LOCALE
if [ -z "$ASSISTANT_ID" ] || [ -z "$AGENT_NAME" ] || [ -z "$PROMPT_NAME" ] || [ -z "$AGENT_TYPE" ] || [ -z "$LOCALE" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi

PROMPT_ID=$(aws qconnect list-ai-prompts --assistant-id "$ASSISTANT_ID" --query "aiPromptSummaries[?name=='$PROMPT_NAME']" | jq -r '.[0].aiPromptId')

# --- 공통 함수: AI 프롬프트 삭제 ---
delete_agent() {
  echo "Searching for existing AI Agent named '$AGENT_NAME'..."
  
  AI_AGENT_JSON=$(aws qconnect list-ai-agents \
    --assistant-id "$ASSISTANT_ID" \
    --query "aiAgentSummaries[?name=='$AGENT_NAME']" \
    --output json)

  if [ "$(echo "$AI_AGENT_JSON" | jq 'length')" -gt 0 ]; then
    echo "$AI_AGENT_JSON" | jq -r '.[].aiAgentId' | while read -r AI_AGENT_ID; do
      echo "Deleting AI Agent ID: $AI_AGENT_ID"
      aws qconnect delete-ai-agent \
        --assistant-id "$ASSISTANT_ID" \
        --ai-agent-id "$AI_AGENT_ID"
      sleep 1
    done
  else
    echo "AI Agent not found, skipping deletion."
  fi
}

# --- 공통 함수: AI 프롬프트 생성 ---
# To-do : Manual Search Type도 동적으로 할당 할 수 있도록 분기
upsert_agent() {
  echo "Creating new AI Agent '$AGENT_NAME'..."
  # echo "ASSISTANT_ID : $ASSISTANT_ID / AGENT_NAME : $AGENT_NAME / AGENT_TYPE : $AGENT_TYPE / PROMPT_ID : $PROMPT_ID / LOCALE : $LOCALE"
  # 입력용 JSON 생성
  INPUT_JSON=$(jq -n \
    --arg assistantId "$ASSISTANT_ID" \
    --arg agentName "$AGENT_NAME" \
    --arg agentType "$AGENT_TYPE" \
    --arg promptId "$PROMPT_ID" \
    --arg locale "$LOCALE" \
    '{
      "assistantId": $assistantId,
      "name": $agentName,
      "type": $agentType,
      "visibilityStatus": "PUBLISHED",
      "configuration": {
        "answerRecommendationAIAgentConfiguration": {
          "answerGenerationAIPromptId": $promptId,
          "locale": $locale
        }
      }
    }')  

  AI_AGENT_JSON=$(aws qconnect list-ai-agents \
    --assistant-id "$ASSISTANT_ID" \
    --query "aiAgentSummaries[?name=='$AGENT_NAME']" \
    --output json)

  if [ "$(echo "$AI_AGENT_JSON" | jq 'length')" -gt 0 ]; then
    echo "$AI_AGENT_JSON" | jq -r '.[].aiAgentId' | while read -r AI_AGENT_ID; do
      echo "Update AI Agent ID: $AI_AGENT_ID"
      aws qconnect update-ai-agent \
        --region "$REGION" \
        --cli-input-json "$INPUT_JSON" | jq .
    done
  else
    echo "AI Agent not found, create new agent."
    # 프롬프트 생성 API 호출
    aws qconnect create-ai-agent \
      --region "$REGION" \
      --cli-input-json "$INPUT_JSON" | jq .
  fi
}


# --- 메인 로직 ---
case "$ACTION" in
  # 생성 또는 업데이트 시: 삭제 후 생성 (Replace)
  upsert)
    # delete_agent
    upsert_agent
    ;;
  
  # 삭제 시: 삭제만 수행
  delete)
    delete_agent
    ;;

  *)
    echo "Error: Invalid action '$ACTION'. Use 'upsert' or 'delete'."
    exit 1
    ;;
esac

echo "Action '$ACTION' completed successfully."


