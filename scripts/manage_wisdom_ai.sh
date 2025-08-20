#!/bin/bash
set -e # 스크립트 실행 중 오류가 발생하면 즉시 중단

if [ "$DELETE_FLAG" == "true" ]
  ACTION="delete"
else
  ACTION="upsert"
fi

# 공통 환경 변수 확인
if [ -z "$ASSISTANT_ID" ] || [ -z "$PROMPT_NAME" ] || [ -z "$PROMPT_TYPE" ] || [ -z "$AGENT_NAME" ] || [ -z "$AGENT_TYPE" ] || [ -z "$LOCALE" ] || [ -z "$ENV" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi

# --- 함수: 단일 AI 프롬프트 생성 ---
# $1: 프롬프트 이름, $2: 프롬프트 내용, $3: 프롬프트 타입
create_single_prompt() {

  local PROMPT_NAME="$1"
  local PROMPT_CONTENT="$2"
  local PROMPT_TYPE="$3"

  echo "--------------------------------------------------"
  echo "Creating new AI Prompt '$PROMPT_NAME' of type '$PROMPT_TYPE'..."

  # 입력용 JSON 생성
  INPUT_JSON=$(jq -n \
    --arg assistantId "$ASSISTANT_ID" \
    --arg promptName "$PROMPT_NAME" \
    --arg promptContent "$PROMPT_CONTENT" \
    --arg modelId "$MODEL_ID" \
    --arg promptType "$PROMPT_TYPE" \
    --arg promptApiFormat "$PROMPT_API_FORMAT" \
    '{
      "assistantId": $assistantId,
      "name": $promptName,
      "apiFormat": $promptApiFormat,
      "modelId": $modelId,
      "templateType": "TEXT",
      "type": $promptType,
      "visibilityStatus": "PUBLISHED",
      "templateConfiguration": {
        "textFullAIPromptEditTemplateConfiguration": {
          "text": $promptContent
        }
      }
    }')
  

  AI_PROMPT_JSON=$(aws qconnect list-ai-prompts \
    --assistant-id "$ASSISTANT_ID" \
    --query "aiPromptSummaries[?name=='$PROMPT_NAME']" \
    --output json)

  if [ "$(echo "$AI_PROMPT_JSON" | jq 'length')" -gt 0 ]; then
    echo "$AI_PROMPT_JSON" | jq -r '.[].aiPromptId' | while read -r AI_PROMPT_ID; do
      echo "Updating AI Prompt ID: $AI_PROMPT_ID"
      UPSERT_AI_PROMPT=$(aws qconnect update-ai-prompt \
        --region $REGION \
        --cli-input-json $INPUT_JSON \
        --output json)
      sleep 1
    done
  else
    echo "AI Prompt not found, create new ai prompt."

    UPSERT_AI_PROMPT=$(aws qconnect create-ai-prompt \
      --region "$REGION" \
      --cli-input-json "$INPUT_JSON" \
      --output json)

  fi
  create_prompt_version $(echo $UPSERT_AI_PROMPT | jq -r '.aiPrompt["aiPromptId"]')
}

create_prompt_version() {

  UPSERT_AI_PROMPT_ID=$1

  CREATED_AI_PROMPT_VERSION=$(aws qconnect create-ai-prompt-version \
    --region "$REGION" \
    --assistant-id $ASSISTANT_ID \
    --ai-prompt-id $UPSERT_AI_PROMPT_ID \
    --output json | jq -r '.versionNumber'
  )


}

# --- 함수: 모든 AI 프롬프트 삭제 ---
delete_prompts() {
  echo "Searching for all existing AI Prompts to delete them..."
  
  local ai_prompt_json=$(aws qconnect list-ai-prompts \
    --assistant-id "$ASSISTANT_ID" \
    --query "aiPromptSummaries" \
    --output json)

  if [ "$(echo "$ai_prompt_json" | jq 'length')" -gt 0 ]; then
    echo "$ai_prompt_json" | jq -r '.[].aiPromptId' | while read -r ai_prompt_id; do
      echo "Deleting AI Prompt ID: $ai_prompt_id"
      aws qconnect delete-ai-prompt \
        --assistant-id "$ASSISTANT_ID" \
        --ai-prompt-id "$ai_prompt_id"
      sleep 1
    done
  else
    echo "No existing AI Prompts found, skipping deletion."
  fi
}


# --- 메인 로직 ---
case "$ACTION" in
  # 생성 또는 업데이트 시: 모든 프롬프트를 삭제하고 전달받은 JSON 리스트로 새로 생성
  upsert)
    if [ -z "$PROMPTS_JSON" ]; then
        echo "Error: PROMPTS_JSON is not set for upsert action."
        exit 1
    fi

    echo "Creating prompts from the provided JSON..."
    # JSON 배열을 jq로 파싱하여 루프 실행
    # jq -c '.[]': compact-output 옵션으로 각 JSON 객체를 한 줄로 출력
    echo "$PROMPTS_JSON" | jq -c '.[]' | while read -r prompt_obj; do
      # 각 객체에서 값 추출
      p_name=$(echo "$prompt_obj" | jq -r '.prompt_name')
      p_content=$(echo "$prompt_obj" | jq -r '.prompt_content')
      p_type=$(echo "$prompt_obj" | jq -r '.prompt_type')
      
      # 단일 프롬프트 생성 함수 호출
      create_single_prompt "$p_name" "$p_content" "$p_type"
    done
    ;;
  
  # 삭제 시: 모든 프롬프트 삭제
  delete)
    delete_prompts
    ;;

  *)
    echo "Error: Invalid action '$ACTION'. Use 'upsert' or 'delete'."
    exit 1
    ;;
esac

echo "--------------------------------------------------"
echo "Action '$ACTION' completed successfully."