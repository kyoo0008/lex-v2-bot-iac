#!/bin/bash
set -e

if [ -z "$ASSISTANT_ID" ] || [ -z "$MODEL_ID" ] || [ -z "$REGION" ] || [ -z "$AGENT_NAME" ] || [ -z "$LOCALE" ] || [ -z "$AGENT_TYPE" ] || [ -z "$ENV" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi


# ==============================================================================
# DEV 환경용 함수
# ==============================================================================
dev_upsert_prompt() {

  local PROMPT_NAME="$1"
  local PROMPT_CONTENT="$2"
  local PROMPT_TYPE="$3"

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

      echo "--------------------------------------------------"
      echo "Updating new AI Prompt '$PROMPT_NAME' of type '$PROMPT_TYPE'..."

      UPSERT_AI_PROMPT=$(aws qconnect update-ai-prompt \
        --region $REGION \
        --cli-input-json $INPUT_JSON \
        --output json)
      sleep 1
    done
  else
    echo "--------------------------------------------------"
    echo "Creating new AI Prompt '$PROMPT_NAME' of type '$PROMPT_TYPE'..."

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

dev_upsert_agent() {
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
      echo "--------------------------------------------------"
      echo "Updating new AI Prompt '$PROMPT_NAME' of type '$PROMPT_TYPE'..."

      aws qconnect update-ai-agent \
        --region "$REGION" \
        --cli-input-json "$INPUT_JSON" > /dev/null
    done
  else
    echo "--------------------------------------------------"
    echo "Creating new AI Prompt '$PROMPT_NAME' of type '$PROMPT_TYPE'..."
    # 프롬프트 생성 API 호출
    aws qconnect create-ai-agent \
      --region "$REGION" \
      --cli-input-json "$INPUT_JSON" > /dev/null
  fi
}

# ==============================================================================
# PROD 환경용 함수
# ==============================================================================
prod_create_prompt_version() {
    local p_name="$1"
    local p_content="$2"

    echo "PROD: Creating new version for prompt '$p_name'..."
    PROMPT_ID=$(aws qconnect list-ai-prompts --assistant-id $ASSISTANT_ID --query "aiPromptSummaries[?name=='$p_name'].aiPromptId" --output text)
    if [ -z "$PROMPT_ID" ]; then
        echo "Error: Prompt '$p_name' not found in prod environment. It must be created first."
        exit 1
    fi
    
    # 내용을 업데이트하고 새 버전 생성
    aws qconnect update-ai-prompt --assistant-id $ASSISTANT_ID --ai-prompt-id $PROMPT_ID \
        --template-configuration "{\"textFullAIPromptEditTemplateConfiguration\":{\"text\":\"$p_content\"}}" > /dev/null

    VERSION_INFO=$(aws qconnect create-ai-prompt-version --assistant-id $ASSISTANT_ID --ai-prompt-id $PROMPT_ID)
    echo "PROD: Created prompt version $(echo $VERSION_INFO | jq -r '.versionNumber') with ID $PROMPT_ID"
    # 전역 변수에 버전 ID 저장
    eval "PROMPT_VERSION_ID_${p_name//-/_}=$PROMPT_ID"
}

prod_create_agent_version() {
    # 답변 생성 프롬프트 ID (이름 규칙 기반)
    local answer_prompt_name="${local_answer_generation_prompt_name}" # Terraform local 변수 이름과 일치시켜야 함
    local answer_prompt_id_var="PROMPT_VERSION_ID_${answer_prompt_name//-/_}"
    local answer_prompt_id="${!answer_prompt_id_var}"

    echo "PROD: Creating new version for agent '$AGENT_NAME' with Prompt ID: $answer_prompt_id..."
    AGENT_ID=$(aws qconnect list-ai-agents --assistant-id $ASSISTANT_ID --query "aiAgentSummaries[?name=='$AGENT_NAME'].aiAgentId" --output text)
    if [ -z "$AGENT_ID" ]; then
        echo "Error: Agent '$AGENT_NAME' not found."
        exit 1
    fi
    
    # 에이전트 설정 업데이트 (연결할 프롬프트 ID 지정)
    aws qconnect update-ai-agent --assistant-id $ASSISTANT_ID --ai-agent-id $AGENT_ID \
        --configuration "{\"answerRecommendationAIAgentConfiguration\":{\"answerGenerationAIPromptId\":\"$answer_prompt_id\",\"locale\":\"$LOCALE\"}}" > /dev/null

    AGENT_VERSION_INFO=$(aws qconnect create-ai-agent-version --assistant-id $ASSISTANT_ID --ai-agent-id $AGENT_ID)
    local new_agent_version_arn=$(echo $AGENT_VERSION_INFO | jq -r '.aiAgentVersion.aiAgentVersionArn')
    echo "PROD: Created agent version $(echo $AGENT_VERSION_INFO | jq -r '.versionNumber') with ARN $new_agent_version_arn"

    # 생성된 새 버전을 Assistant의 기본값으로 설정
    echo "PROD: Setting new agent version as default for assistant..."
    aws qconnect update-assistant-ai-agent --assistant-id $ASSISTANT_ID --ai-agent-arn $new_agent_version_arn > /dev/null
}


# ==============================================================================
# 메인 로직
# ==============================================================================
case "$ENV" in
  dev)
    echo "== Running in DEV mode =="
    # dev 모드에서는 전달받은 prompts_json으로 최신 DRAFT 버전을 생성/업데이트
    echo "$PROMPTS_JSON" | jq -c '.[]' | while read -r prompt_obj; do
      p_name=$(echo "$prompt_obj" | jq -r '.prompt_name')
      p_content=$(echo "$prompt_obj" | jq -r '.prompt_content')
      p_type=$(echo "$prompt_obj" | jq -r '.prompt_type')
      dev_upsert_prompt "$p_name" "$p_content" "$p_type"
    done
    dev_upsert_agent
    ;;
    
  prod)
    echo "== Running in PROD mode =="
    # prod 모드에서는 전달받은 prompts_json으로 각 프롬프트의 '새 버전'을 생성
    echo "$PROMPTS_JSON" | jq -c '.[]' | while read -r prompt_obj; do
      p_name=$(echo "$prompt_obj" | jq -r '.prompt_name')
      p_content=$(echo "$prompt_obj" | jq -r '.prompt_content')
      prod_create_prompt_version "$p_name" "$p_content"
    done
    
    # 프롬프트 버전 생성이 완료된 후, 이를 사용하는 '새 에이전트 버전'을 생성하고 Assistant에 연결
    prod_create_agent_version
    ;;
    
  *)
    echo "Error: Invalid ENV value '$ENV'. Use 'dev' or 'prod'."
    exit 1
    ;;
esac

echo "Action for ENV '$ENV' completed successfully."