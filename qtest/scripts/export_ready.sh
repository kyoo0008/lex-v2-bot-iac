#!/bin/bash
# scripts/export_ready_versions.sh

set -e
export AWS_REGION="ap-northeast-2" # 실제 리전으로 변경

OUTPUT_FILE="deployment_vars.json"
AGENT_NAME_PREFIX="qconnect-agent" # Terraform에서 정의한 prefix와 일치

# 4개 로케일
LOCALES=("en_US" "ko_KR" "zh_CN" "ja_JP")

echo "Exporting 'ready_version' configurations from AWS..."
JSON_CONTENT=$(jq -n '{}')

for LOCALE in "${LOCALES[@]}"; do
    echo "Processing locale: $LOCALE"
    ASSISTANT_NAME="qconnect-assistant-$LOCALE"
    AGENT_NAME="${AGENT_NAME_PREFIX}-$LOCALE"

    # 1. Assistant ID 가져오기
    ASSISTANT_ID=$(aws qconnect list-assistants --query "assistantSummaries[?name=='$ASSISTANT_NAME'].assistantId" --output text)
    if [ -z "$ASSISTANT_ID" ]; then
        echo "Error: Assistant '$ASSISTANT_NAME' not found."
        exit 1
    fi

    # 2. Agent ID 가져오기
    AGENT_ID=$(aws qconnect list-ai-agents --assistant-id $ASSISTANT_ID --query "aiAgentSummaries[?name=='$AGENT_NAME'].aiAgentId" --output text)
    if [ -z "$AGENT_ID" ]; then
        echo "Error: Agent '$AGENT_NAME' not found for assistant '$ASSISTANT_NAME'."
        exit 1
    fi
    
    # 3. Agent의 버전 목록에서 'ready_version' 태그가 있는 버전 찾기
    AGENT_VERSIONS=$(aws qconnect list-ai-agent-versions --assistant-id $ASSISTANT_ID --ai-agent-id $AGENT_ID --query "aiAgentVersionSummaries" --output json)
    READY_VERSION_ARN=""
    READY_VERSION_NUM=""

    for row in $(echo "${AGENT_VERSIONS}" | jq -r '.[] | @base64'); do
        _jq() {
         echo ${row} | base64 --decode | jq -r ${1}
        }
        VERSION_ARN=$(_jq '.aiAgentVersionArn')
        TAGS=$(aws resourcegroupstaggingapi get-resources --resource-arn-list $VERSION_ARN --query "ResourceTagMappingList[0].Tags" --output json)
        
        READY_TAG_VALUE=$(echo $TAGS | jq -r '.[] | select(.Key == "ready_version") | .Value')

        if [ ! -z "$READY_TAG_VALUE" ] && [ "$READY_TAG_VALUE" != "null" ]; then
            READY_VERSION_ARN=$VERSION_ARN
            READY_VERSION_NUM=$(_jq '.versionNumber')
            echo "Found ready_version: $READY_TAG_VALUE on Agent Version ARN: $READY_VERSION_ARN"
            break
        fi
    done

    if [ -z "$READY_VERSION_ARN" ]; then
        echo "Error: No agent version with 'ready_version' tag found for agent '$AGENT_NAME'."
        exit 1
    fi

    # 4. 해당 버전의 Agent 상세 정보 가져오기 (연결된 프롬프트 ID 등)
    AGENT_DETAILS=$(aws qconnect get-ai-agent-version --assistant-id $ASSISTANT_ID --ai-agent-id $AGENT_ID --version-number $READY_VERSION_NUM --output json)
    
    # 5. 프롬프트 정보 추출 및 파일 내용 저장
    PROMPTS_ARRAY=$(jq -n '[]')
    # 예: 답변 생성 프롬프트 ID 추출
    ANSWER_PROMPT_ID=$(echo $AGENT_DETAILS | jq -r '.aiAgentVersion.configuration.answerRecommendationAIAgentConfiguration.answerGenerationAIPromptId')
    
    if [ ! -z "$ANSWER_PROMPT_ID" ] && [ "$ANSWER_PROMPT_ID" != "null" ]; then
        PROMPT_DETAILS=$(aws qconnect get-ai-prompt --assistant-id $ASSISTANT_ID --ai-prompt-id $ANSWER_PROMPT_ID --output json)
        PROMPT_NAME=$(echo $PROMPT_DETAILS | jq -r '.aiPrompt.name')
        PROMPT_CONTENT=$(echo $PROMPT_DETAILS | jq -r '.aiPrompt.templateConfiguration.textFullAIPromptEditTemplateConfiguration.text')
        
        PROMPT_OBJ=$(jq -n --arg name "$PROMPT_NAME" --arg content "$PROMPT_CONTENT" --arg type "ANSWER_GENERATION" \
            '{prompt_name: $name, prompt_content: $content, prompt_type: $type}')
        PROMPTS_ARRAY=$(echo $PROMPTS_ARRAY | jq --argjson obj "$PROMPT_OBJ" '. + [$obj]')
    fi
    # (필요시 QUERY_REFORMULATION 등 다른 프롬프트 타입도 동일하게 추가)

    # 6. 최종 JSON에 로케일별 정보 추가
    LOCALE_DATA=$(jq -n --argjson prompts "$PROMPTS_ARRAY" '{prompts: $prompts, guardrails: []}') # 가드레일은 예시로 비워둠
    JSON_CONTENT=$(echo $JSON_CONTENT | jq --arg key "$LOCALE" --argjson value "$LOCALE_DATA" '. + {($key): $value}')
done

echo "$JSON_CONTENT" | jq '.' > $OUTPUT_FILE
echo "Exported configuration to $OUTPUT_FILE"
