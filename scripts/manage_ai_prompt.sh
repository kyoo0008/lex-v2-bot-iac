#!/bin/bash
set -e # 스크립트 실행 중 오류가 발생하면 즉시 중단

# --- 입력 파라미터 ---
ACTION="$1"

# 환경 변수에서 Terraform 값들을 가져옵니다.
# ASSISTANT_ID, PROMPT_NAME, MODEL_ID, REGION, PROMPT_CONTENT
if [ -z "$ASSISTANT_ID" ] || [ -z "$PROMPT_NAME" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi

# --- 공통 함수: AI 프롬프트 삭제 ---
delete_prompt() {
  echo "Searching for existing AI Prompt named '$PROMPT_NAME'..."
  
  AI_PROMPT_JSON=$(aws qconnect list-ai-prompts \
    --assistant-id "$ASSISTANT_ID" \
    --query "aiPromptSummaries[?name=='$PROMPT_NAME']" \
    --output json)

  if [ "$(echo "$AI_PROMPT_JSON" | jq 'length')" -gt 0 ]; then
    echo "$AI_PROMPT_JSON" | jq -r '.[].aiPromptId' | while read -r AI_PROMPT_ID; do
      echo "Deleting AI Prompt ID: $AI_PROMPT_ID"
      aws qconnect delete-ai-prompt \
        --assistant-id "$ASSISTANT_ID" \
        --ai-prompt-id "$AI_PROMPT_ID"
      sleep 1
    done
  else
    echo "AI Prompt not found, skipping deletion."
  fi
}

# --- 공통 함수: AI 프롬프트 생성 ---
create_prompt() {
  echo "Creating new AI Prompt '$PROMPT_NAME'..."

  # 입력용 JSON 생성
  INPUT_JSON=$(jq -n \
    --arg assistantId "$ASSISTANT_ID" \
    --arg promptName "$PROMPT_NAME" \
    --arg promptContent "$PROMPT_CONTENT" \
    --arg modelId "$MODEL_ID" \
    '{
      "assistantId": $assistantId,
      "name": $promptName,
      "apiFormat": "TEXT_COMPLETIONS",
      "modelId": $modelId,
      "templateType": "TEXT",
      "type": "ANSWER_GENERATION",
      "visibilityStatus": "PUBLISHED",
      "templateConfiguration": {
        "textFullAIPromptEditTemplateConfiguration": {
          "text": $promptContent
        }
      }
    }')
  
  # 프롬프트 생성 API 호출
  aws qconnect create-ai-prompt \
    --region "$REGION" \
    --cli-input-json "$INPUT_JSON" | jq .
}


# --- 메인 로직 ---
case "$ACTION" in
  # 생성 또는 업데이트 시: 삭제 후 생성 (Replace)
  create)
    delete_prompt
    create_prompt
    ;;
  
  # 삭제 시: 삭제만 수행
  delete)
    delete_prompt
    ;;

  *)
    echo "Error: Invalid action '$ACTION'. Use 'create' or 'delete'."
    exit 1
    ;;
esac

echo "Action '$ACTION' completed successfully."
