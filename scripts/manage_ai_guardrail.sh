#!/bin/bash
set -e # 스크립트 실행 중 오류가 발생하면 즉시 중단

# --- 입력 파라미터 ---
ACTION="$1"

# 환경 변수에서 Terraform 값들을 가져옵니다.
# ASSISTANT_ID, GUARDRAIL_NAME, MODEL_ID, REGION, GUARDRAIL_CONTENT
if [ -z "$ASSISTANT_ID" ] || [ -z "$GUARDRAIL_NAME" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi

# --- 공통 함수: AI 프롬프트 삭제 ---
delete_guardrail() {
  echo "Searching for existing AI Guardrail named '$GUARDRAIL_NAME'..."
  
  AI_GUARDRAIL_JSON=$(aws qconnect list-ai-guardrails \
    --assistant-id "$ASSISTANT_ID" \
    --query "aiGuardrailSummaries[?name=='$GUARDRAIL_NAME']" \
    --output json)

  if [ "$(echo "$AI_GUARDRAIL_JSON" | jq 'length')" -gt 0 ]; then
    echo "$AI_GUARDRAIL_JSON" | jq -r '.[].aiGuardrailId' | while read -r AI_GUARDRAIL_ID; do
      echo "Deleting AI Guardrail ID: $AI_GUARDRAIL_ID"
      aws qconnect delete-ai-guardrail \
        --assistant-id "$ASSISTANT_ID" \
        --ai-guardrail-id "$AI_GUARDRAIL_ID"
      sleep 1
    done
  else
    echo "AI Guardrail not found, skipping deletion."
  fi
}

# --- 공통 함수: AI 프롬프트 생성 ---
create_guardrail() {
  echo "Creating new AI Guardrail '$GUARDRAIL_NAME'..."

  # 입력용 JSON 생성
  INPUT_JSON=$(jq -n \
    --arg assistantId "$ASSISTANT_ID" \
    --arg guardrailName "$GUARDRAIL_NAME" \
    --arg guardrailContent "$GUARDRAIL_CONTENT" \
    --arg modelId "$MODEL_ID" \
    '{
      "assistantId": $assistantId,
      "name": $guardrailName,
      "apiFormat": "TEXT_COMPLETIONS",
      "modelId": $modelId,
      "templateType": "TEXT",
      "type": "ANSWER_GENERATION",
      "visibilityStatus": "PUBLISHED",
      "templateConfiguration": {
        "textFullAIGuardrailEditTemplateConfiguration": {
          "text": $guardrailContent
        }
      }
    }')
  
  # 프롬프트 생성 API 호출
  aws qconnect create-ai-guardrail \
    --region "$REGION" \
    --cli-input-json "$INPUT_JSON" | jq .
}


# --- 메인 로직 ---
case "$ACTION" in
  # 생성 또는 업데이트 시: 삭제 후 생성 (Replace)
  create)
    delete_guardrail
    create_guardrail
    ;;
  
  # 삭제 시: 삭제만 수행
  delete)
    delete_guardrail
    ;;

  *)
    echo "Error: Invalid action '$ACTION'. Use 'create' or 'delete'."
    exit 1
    ;;
esac

echo "Action '$ACTION' completed successfully."
