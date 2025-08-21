#!/bin/bash
set -eo pipefail

# Terraform으로부터 전달받은 필수 환경 변수들이 설정되었는지 확인합니다.
if [ -z "$ASSISTANT_ID" ] || [ -z "$MODEL_ID" ] || [ -z "$REGION" ] || [ -z "$LOCALE" ] || [ -z "$AGENTS_JSON" ] \
   || [ -z "$PROMPTS_JSON" ] || [ -z "$GUARDRAILS_JSON" ] || [ -z "$ENV" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi

# 프롬프트 이름과 'ID:버전'을 매핑하기 위한 전역 연관 배열
# declare -r PROMPT_IDS
# PROMPT_IDS
# ==============================================================================
# Helper Functions
# ==============================================================================

# 프롬프트의 최신 DRAFT 버전을 기반으로 새로운 버전을 생성하고, 그 버전 번호를 반환합니다.
create_prompt_version() {
  local prompt_id="$1"
  if [ -z "$prompt_id" ]; then
    echo "Error: Prompt ID is required to create a version." >&2
    return 1
  fi

  # echo "Creating a new version for prompt ID '$prompt_id'..."
  local version_info
  version_info=$(aws qconnect create-ai-prompt-version \
    --region "$REGION" \
    --assistant-id "$ASSISTANT_ID" \
    --ai-prompt-id "$prompt_id")
  
  local new_version
  new_version=$(echo "$version_info" | jq -r '.versionNumber')
  
  if [ -z "$new_version" ] || [ "$new_version" == "null" ]; then
      echo "Error: Failed to create or retrieve new prompt version for ID '$prompt_id'." >&2
      exit 1
  fi

  echo "$new_version" # 버전 번호를 표준 출력으로 반환
}


# AGENT의 최신 DRAFT 버전을 기반으로 새로운 버전을 생성하고, 그 버전 번호를 반환합니다.
create_agent_version() {
  local agent_id="$1"
  if [ -z "$agent_id" ]; then
    echo "Error: Agent ID is required to create a version." >&2
    return 1
  fi

  # echo "Creating a new version for agent ID '$agent_id'..."
  local version_info
  version_info=$(aws qconnect create-ai-agent-version \
    --region "$REGION" \
    --assistant-id "$ASSISTANT_ID" \
    --ai-agent-id "$agent_id")
  
  local new_version
  new_version=$(echo "$version_info" | jq -r '.versionNumber')
  
  if [ -z "$new_version" ] || [ "$new_version" == "null" ]; then
      echo "Error: Failed to create or retrieve new agent version for ID '$agent_id'." >&2
      exit 1
  fi

  echo "$new_version" # 버전 번호를 표준 출력으로 반환
}

# use_flag가 false인 프롬프트를 삭제합니다.
delete_unused_prompts() {
  echo "=================================================="
  echo "Checking for unused prompts to delete..."
  
  echo "$PROMPTS_JSON" | jq -c '.[] | select(.use_flag == "false")' | while read -r prompt_obj; do
    local prompt_name
    prompt_name=$(echo "$prompt_obj" | jq -r '.prompt_name')
    
    echo "Attempting to delete unused prompt: '$prompt_name'"
    
    local existing_prompt_id
    existing_prompt_id=$(aws qconnect list-ai-prompts \
      --assistant-id "$ASSISTANT_ID" \
      --region "$REGION" \
      --query "aiPromptSummaries[?name=='$prompt_name'].aiPromptId" \
      --output text)
      
    if [ -n "$existing_prompt_id" ]; then
      echo "Found existing prompt '$prompt_name' with ID '$existing_prompt_id'. Deleting..."
      aws qconnect delete-ai-prompt \
        --assistant-id "$ASSISTANT_ID" \
        --ai-prompt-id "$existing_prompt_id" \
        --region "$REGION"
      echo "Successfully deleted prompt '$prompt_name'."
    else
      echo "Prompt '$prompt_name' not found. Nothing to delete."
    fi
  done
  echo "Finished checking for unused prompts."
}

# use_flag가 false인 에이전트를 삭제합니다.
delete_unused_agents() {
  echo "=================================================="
  echo "Checking for unused agents to delete..."
  
  echo "$AGENTS_JSON" | jq -c '.[] | select(.use_flag == "false")' | while read -r agent_obj; do
    local agent_name
    agent_name=$(echo "$agent_obj" | jq -r '.agent_name')
    
    echo "Attempting to delete unused agent: '$agent_name'"
    
    local existing_agent_id
    existing_agent_id=$(aws qconnect list-ai-agents \
      --assistant-id "$ASSISTANT_ID" \
      --region "$REGION" \
      --query "aiAgentSummaries[?name=='$agent_name'].aiAgentId" \
      --output text)
      
    if [ -n "$existing_agent_id" ]; then
      echo "Found existing agent '$agent_name' with ID '$existing_agent_id'. Deleting..."
      aws qconnect delete-ai-agent \
        --assistant-id "$ASSISTANT_ID" \
        --ai-agent-id "$existing_agent_id" \
        --region "$REGION"
      echo "Successfully deleted agent '$agent_name'."
    else
      echo "Agent '$agent_name' not found. Nothing to delete."
    fi
  done
  echo "Finished checking for unused agents."
}

# ==============================================================================
# 메인 로직
# ==============================================================================
main() {
  # 1. 미사용 에이전트, 프롬프트를 먼저 삭제합니다.
  delete_unused_prompts
  delete_unused_agents


  echo "== Running in $ENV mode for ASSISTANT_ID: $ASSISTANT_ID =="
  local ansgen_prompt_id_version
  local preproc_prompt_id_version
  # 2. 모든 프롬프트를 생성/업데이트합니다.
  while IFS= read -r prompt_obj; do
    # dev_upsert_prompt \
    #   "$(echo "$prompt_obj" | jq -r '.prompt_name')" \
    #   "$(echo "$prompt_obj" | jq -r '.prompt_content')" \
    #   "$(echo "$prompt_obj" | jq -r '.prompt_type')" \
    #   "$(echo "$prompt_obj" | jq -r '.prompt_api_format')"
    prompt_name="$(echo "$prompt_obj" | jq -r '.prompt_name')" 
    prompt_content="$(echo "$prompt_obj" | jq -r '.prompt_content')" 
    prompt_type="$(echo "$prompt_obj" | jq -r '.prompt_type')" 
    prompt_api_format="$(echo "$prompt_obj" | jq -r '.prompt_api_format')"

    echo "--------------------------------------------------"
    echo "Processing prompt '$prompt_name' of type '$prompt_type' for DEV..."
    
    existing_prompt_id=$(aws qconnect list-ai-prompts \
      --assistant-id "$ASSISTANT_ID" --region "$REGION" --query "aiPromptSummaries[?name=='$prompt_name'].aiPromptId" --output text)

    local upserted_prompt
    if [ -n "$existing_prompt_id" ]; then
      echo "Updating existing prompt '$prompt_name'..."

      input_json=$(jq -n \
      --arg assistantId "$ASSISTANT_ID" --arg promptId "$existing_prompt_id" --arg content "$prompt_content" \
      --arg modelId "$MODEL_ID" --arg type "$prompt_type" --arg promptApiFormat "$prompt_api_format" \
      '{
          "aiPromptId": $promptId,
          "assistantId": $assistantId,
          "templateConfiguration": {
              "textFullAIPromptEditTemplateConfiguration": {
                  "text": $content
              }
          },
          "visibilityStatus": "PUBLISHED"
      }')
      # '{"assistantId": $assistantId, "name": $name, "modelId": $modelId, "type": $type, "visibilityStatus": "PUBLISHED", "templateType": "TEXT", "apiFormat": $promptApiFormat, "templateConfiguration": {"textFullAIPromptEditTemplateConfiguration": {"text": $content}}}')


      upserted_prompt=$(aws qconnect update-ai-prompt --region "$REGION" --cli-input-json "$input_json" --output json)
    else
      echo "Creating new prompt '$prompt_name'..."

      input_json=$(jq -n \
      --arg assistantId "$ASSISTANT_ID" --arg name "$prompt_name" --arg content "$prompt_content" \
      --arg modelId "$MODEL_ID" --arg type "$prompt_type" --arg promptApiFormat "$prompt_api_format" \
      '{
          "assistantId": $assistantId, 
          "name": $name, 
          "modelId": $modelId, 
          "type": $type, 
          "visibilityStatus": "PUBLISHED", 
          "templateType": "TEXT", 
          "apiFormat": $promptApiFormat, 
          "templateConfiguration": {
              "textFullAIPromptEditTemplateConfiguration": {
                  "text": $content
              }
          }
        }')

      upserted_prompt=$(aws qconnect create-ai-prompt --region "$REGION" --cli-input-json "$input_json" --output json)
    fi
    
    local new_prompt_id
    new_prompt_id=$(echo "$upserted_prompt" | jq -r '.aiPrompt.aiPromptId')
    
    local new_version
    new_version=$(create_prompt_version "$new_prompt_id")
    if [ "$prompt_type" == "SELF_SERVICE_ANSWER_GENERATION" ]; then
      ansgen_prompt_id_version="${new_prompt_id}:${new_version}"
      echo "Stored Prompt ID and Version ===> '$ansgen_prompt_id_version' for '$prompt_name'"
    elif [ "$prompt_type" == "SELF_SERVICE_PRE_PROCESSING" ]; then
      preproc_prompt_id_version="${new_prompt_id}:${new_version}"
      echo "Stored Prompt ID and Version ===> '$preproc_prompt_id_version' for '$prompt_name'"
    fi
    
  done< <(echo "$PROMPTS_JSON" | jq -c '.[] | select(.use_flag == "true")') 

  # 3. 사용 설정된 모든 에이전트를 생성/업데이트합니다.
  while IFS= read -r agent_obj; do
      local agent_name="$(echo "$agent_obj" | jq -r '.agent_name')" 
      local agent_type="$(echo "$agent_obj" | jq -r '.agent_type')" 
      
      echo "--------------------------------------------------"
      echo "Processing agent '$agent_name' of type '$agent_type' for DEV..."

      
      # local pre_proc_id_with_version="${PROMPT_IDS["example_self_service_pre_processing_prompt"]}"
      # local answer_gen_id_with_version="${PROMPT_IDS["example_self_service_answer_generation_prompt"]}"
      if [ -z "$preproc_prompt_id_version" ] || [ -z "$ansgen_prompt_id_version" ]; then echo "Error: Prompt ID:Versions for self service not found." >&2; exit 1; fi
      configuration_json=$(jq -n --arg preId "$preproc_prompt_id_version" --arg ansId "$ansgen_prompt_id_version" \
        '{"selfServiceAIAgentConfiguration": {"selfServicePreProcessingAIPromptId": $preId, "selfServiceAnswerGenerationAIPromptId": $ansId}}')

      local existing_agent_id
      existing_agent_id=$(aws qconnect list-ai-agents --assistant-id "$ASSISTANT_ID" --region "$REGION" --query "aiAgentSummaries[?name=='$agent_name'].aiAgentId" --output text)


      local upserted_agent
      if [ -n "$existing_agent_id" ]; then
        echo "Updating existing agent '$agent_name'..."

        input_json=$(jq -n \
        --arg assistantId "$ASSISTANT_ID" --arg name "$agent_name" --arg type "$agent_type" --arg agentId "$existing_agent_id" --argjson config "$configuration_json" \
        '{
            "assistantId": $assistantId,
            "aiAgentId": $agentId,
            "assistantId": $assistantId,
            "configuration": $config,
            "visibilityStatus": "PUBLISHED"
        }')
      
        upserted_agent=$(aws qconnect update-ai-agent --region "$REGION" --cli-input-json "$input_json" --output json)
      else
        echo "Creating new agent '$agent_name'..."

        input_json=$(jq -n \
        --arg assistantId "$ASSISTANT_ID" --arg name "$agent_name" --arg type "$agent_type" --argjson config "$configuration_json" \
        '{
          "assistantId": $assistantId,
          "name": $name,
          "type": $type,
          "visibilityStatus": "PUBLISHED",
          "configuration": $config
        }')
        upserted_agent=$(aws qconnect create-ai-agent --region "$REGION" --cli-input-json "$input_json" --output json)
      fi

      echo "Agent '$agent_name' processed successfully."

      local new_agent_id
      new_agent_id=$(echo "$upserted_agent" | jq -r '.aiAgent.aiAgentId')

      local new_agent_version
      new_agent_version=$(create_agent_version "$new_agent_id")

      echo "Agent '$agent_name' version $new_agent_version created successfully."
  done< <(echo "$AGENTS_JSON" | jq -c '.[] | select(.use_flag == "true")') 
  
  self_service_agent_id_version="${new_agent_id}:${new_agent_version}"
  configuration_json=$(jq -n --arg aiAgentId "$self_service_agent_id_version" \
        '{"aiAgentId": $aiAgentId}')

  input_json=$(jq -n \
        --arg assistantId "$ASSISTANT_ID" --arg name "$agent_name" --arg type "$agent_type" --arg agentId "$existing_agent_id" --argjson config "$configuration_json" \
        '{
            "assistantId": $assistantId,
            "aiAgentType": "SELF_SERVICE",
            "configuration": $config
        }')

  aws qconnect update-assistant-ai-agent \
    --region "$REGION" \
    --cli-input-json "$input_json" \
    --output json > /dev/null

  echo "=================================================="
  echo "Action for ENV '$ENV' on locale '$LOCALE' completed successfully."
}

main