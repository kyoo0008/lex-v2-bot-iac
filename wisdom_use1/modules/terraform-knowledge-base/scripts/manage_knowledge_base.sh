#!/bin/bash
set -e # 스크립트 실행 중 오류가 발생하면 즉시 중단

# --- 입력 파라미터 처리 ---
ACTION="$1"

if [ -z "$KMS_KEY_ID_ARN" ] || [ -z "$CONTENT_PATH" ] || [ -z "$KNOWLEDGE_BASE_NAME" ] || [ -z "$ASSISTANT_ARN" ] || [ -z "$CONNECT_INSTANCE_ID" ] || [ -z "$OUTPUT_PATH" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi


ASSISTANT_ID=$(echo "$ASSISTANT_ARN" | awk -F'/' '{print $NF}')


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
    --assistant-id $ASSISTANT_ID \
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


start_content_upload() {
  KNOWLEDGE_BASE_ID=$1
  # ================================================================================
  # Start Content Upload
  # ================================================================================
  if [ ! -d "$CONTENT_PATH" ]; then
    echo "Error: Content directory not found at $CONTENT_PATH"
    exit 1
  fi
  # 지원되는 KB Content 확장자 .pdf, .txt, .docx, .html/.htm 
  find "$CONTENT_PATH" -type f \( -name "*.docx" -o -name "*.txt" -o -name "*.pdf" \) | while read -r FILE_PATH; do
    echo "--------------------------------------------------"
    echo "Processing file: $FILE_PATH"

    # 파일 크기 확인
    # 1MB를 바이트 단위로 정의 (1024 * 1024)
    MAX_SIZE_BYTES=1048576
    
    # stat 명령어를 사용하여 파일 크기를 바이트 단위로 가져옵니다.
    # (macOS/BSD의 경우 stat -f%z "$FILE_PATH")
    # FILE_SIZE=$(stat -c%s "$FILE_PATH")
    FILE_SIZE=$(stat -f%z "$FILE_PATH")
    

    if [ "$FILE_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
      # 파일 크기를 MB 단위로 변환하여 사용자에게 보여주기 (소수점 2자리)
      FILE_SIZE_MB=$(awk -v size="$FILE_SIZE" 'BEGIN { printf "%.2f", size / 1024 / 1024 }')
      echo "Skipping file '$FILE_PATH'. Size (${FILE_SIZE_MB}MB) exceeds 1MB limit."
      continue # 현재 파일 처리를 건너뛰고 다음 파일로 넘어갑니다.
    fi
    # --- 로직 추가 끝 ---

    CONTENT_TYPE=""
    if [[ "$FILE_PATH" == *.docx ]]; then
      CONTENT_TYPE="application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    elif [[ "$FILE_PATH" == *.txt ]]; then
      CONTENT_TYPE="text/plain"
    elif [[ "$FILE_PATH" == *.pdf ]]; then
      CONTENT_TYPE="application/pdf"
    else
      echo "Skipping unsupported file type: $FILE_PATH"
      continue
    fi
    echo "Content-Type: $CONTENT_TYPE"

    CONTENT_NAME=$(basename "$FILE_PATH")

    echo "Starting upload for '$CONTENT_NAME'..."
    UPLOAD_INFO_JSON=$(aws qconnect start-content-upload \
      --knowledge-base-id "$KNOWLEDGE_BASE_ID" \
      --content-type "$CONTENT_TYPE" \
      --output json)

    UPLOAD_ID=$(echo "$UPLOAD_INFO_JSON" | jq -r '.uploadId')
    UPLOAD_URL=$(echo "$UPLOAD_INFO_JSON" | jq -r '.url')

    # AWS가 요구하는 헤더 정보를 JSON으로 추출
    CONTENT_TYPE=$(echo "$UPLOAD_INFO_JSON" | jq -r '.headersToInclude["content-type"]')
    HOST=$(echo "$UPLOAD_INFO_JSON" | jq -r '.headersToInclude["host"]')
    X_AMZ_ACL=$(echo "$UPLOAD_INFO_JSON" | jq -r '.headersToInclude["x-amz-acl"]')
    X_AMZ_SERVER_SIDE_ENCRYPTION=$(echo "$UPLOAD_INFO_JSON" | jq -r '.headersToInclude["x-amz-server-side-encryption"]')
    X_AMZ_SERVER_SIDE_ENCRYPTION_AWS_KMS_KEY_ID=$(echo "$UPLOAD_INFO_JSON" | jq -r '.headersToInclude["x-amz-server-side-encryption-aws-kms-key-id"]')
    X_AMZ_SERVER_SIDE_ENCRYPTION_CONTEXT=$(echo "$UPLOAD_INFO_JSON" | jq -r '.headersToInclude["x-amz-server-side-encryption-context"]')

    
    echo "Uploading data (Upload ID: $UPLOAD_ID)..."

    upload_response=$(curl --silent --write-out "HTTP_STATUS:%{http_code}" -X PUT -T "$FILE_PATH" "$UPLOAD_URL" -H "content-type: $CONTENT_TYPE" -H "host: $HOST" -H "x-amz-acl: $X_AMZ_ACL" -H "x-amz-server-side-encryption: $X_AMZ_SERVER_SIDE_ENCRYPTION" -H "x-amz-server-side-encryption-aws-kms-key-id: $X_AMZ_SERVER_SIDE_ENCRYPTION_AWS_KMS_KEY_ID" -H "x-amz-server-side-encryption-context: $X_AMZ_SERVER_SIDE_ENCRYPTION_CONTEXT" )
    
    # HTTP 상태 코드를 확인하여 성공 여부 판단
    http_status=$(echo "$upload_response" | sed -e 's/.*HTTP_STATUS://')
    if [ "$http_status" -ne 200 ]; then
        echo "Error: curl upload failed with status $http_status."
        # 실제 응답 내용이 필요하면 아래 주석 해제
        # echo "Response body: $(echo "$upload_response" | sed -e 's/HTTP_STATUS:.*//')"
        exit 1
    fi

    echo "Creating content metadata..."
    aws qconnect create-content \
      --knowledge-base-id "$KNOWLEDGE_BASE_ID" \
      --name "$CONTENT_NAME" \
      --upload-id "$UPLOAD_ID" > /dev/null

    echo "Successfully uploaded '$CONTENT_NAME'."
  done

  echo "--------------------------------------------------"
  echo "All files have been processed."
}

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
  KNOWLEDGE_BASE_ID=$1
  echo "Creating association for assistant($ASSISTANT_ID) and kb($KNOWLEDGE_BASE_ID) "
  aws qconnect create-assistant-association \
    --assistant-id "$ASSISTANT_ID" \
    --association-type "KNOWLEDGE_BASE" \
    --association "{\"knowledgeBaseId\": \"$KNOWLEDGE_BASE_ID\"}" > /dev/null

  echo "Successfully Created Association"
}

delete_contents() {
  KNOWLEDGE_BASE_ID=$1
  # ========================================================================================
  # Delete Contents
  # ========================================================================================
  echo "Deleting Contents for KnowledgeBase ID: $KNOWLEDGE_BASE_ID"
  CONTENTS_JSON=$(aws qconnect list-contents \
    --knowledge-base-id $KNOWLEDGE_BASE_ID \
    --query "contentSummaries[?knowledgeBaseId=='$KNOWLEDGE_BASE_ID']" \
    --output json)
  
  if [ "$(echo "$CONTENTS_JSON" | jq 'length')" -gt 0 ]; then
    echo "$CONTENTS_JSON" | jq -r '.[].contentId' | while read -r CONTENT_ID; do
      echo "Deleting Content ID: $CONTENT_ID"
      aws qconnect delete-content \
        --knowledge-base-id "$KNOWLEDGE_BASE_ID" \
        --content-id "$CONTENT_ID"
      sleep 1
    done
  else
    echo "Contents not found, skipping deletion."
  fi
  # ========================================================================================
}
delete_knowledge_base() {
  echo "Searching for existing KnowledgeBase named '$KNOWLEDGE_BASE_NAME'..."
  
  KNOWLEDGE_BASE_JSON=$(aws qconnect list-knowledge-bases \
    --query "knowledgeBaseSummaries[?name=='$KNOWLEDGE_BASE_NAME']" \
    --output json)

  if [ "$(echo "$KNOWLEDGE_BASE_JSON" | jq 'length')" -gt 0 ]; then
    echo "$KNOWLEDGE_BASE_JSON" | jq -r '.[].knowledgeBaseId' | while read -r KNOWLEDGE_BASE_ID; do
      delete_contents $KNOWLEDGE_BASE_ID


      echo "Deleting KnowledgeBase ID: $KNOWLEDGE_BASE_ID"
      aws qconnect delete-knowledge-base \
        --knowledge-base-id "$KNOWLEDGE_BASE_ID"

      echo "KnowledgeBase delete Finished : $KNOWLEDGE_BASE_ID"

      sleep 1

    done
    
  else
    echo "KnowledgeBase not found, skipping deletion."
  fi

  # if [ "$LOCALE" == "$CONNECT_ASSOCIATION_LOCALE" ]; then
  #   delete_connect_associations_by_type "WISDOM_ASSISTANT"
  #   delete_connect_associations_by_type "WISDOM_KNOWLEDGE_BASE"
  # fi
  delete_assistant_associations
}
# --- create_knowledge_base 함수 수정 ---
create_knowledge_base() {
  echo "Creating new KnowledgeBase '$KNOWLEDGE_BASE_NAME'..." >&2

  INPUT_JSON=$(jq -n \
    --arg knowledgeBaseName "$KNOWLEDGE_BASE_NAME" \
    --arg kmsKeyIdArn "$KMS_KEY_ID_ARN" \
    '{
      "name": $knowledgeBaseName,
      "knowledgeBaseType": "CUSTOM",
      "serverSideEncryptionConfiguration": { "kmsKeyId": $kmsKeyIdArn },
      "tags": { "AmazonConnectEnabled": "True" }
    }')
  
  CREATED_KB_JSON=$(aws qconnect create-knowledge-base \
    --region "$REGION" \
    --cli-input-json "$INPUT_JSON" \
    --output json)

  CREATED_KNOWLEDGE_BASE_ID=$(echo "$CREATED_KB_JSON" | jq -r '.knowledgeBase.knowledgeBaseId')
  CREATED_KNOWLEDGE_BASE_ARN=$(echo "$CREATED_KB_JSON" | jq -r '.knowledgeBase.knowledgeBaseArn')

  echo "KnowledgeBase created(id : $CREATED_KNOWLEDGE_BASE_ID). Starting content upload..." >&2
  start_content_upload "$CREATED_KNOWLEDGE_BASE_ID"
  
  ASSISTANT_ID=$(echo "$ASSISTANT_ARN" | awk -F'/' '{print $NF}')
  create_assistant_associations "$CREATED_KNOWLEDGE_BASE_ID"

  jq -n \
    --arg id "$CREATED_KNOWLEDGE_BASE_ID" \
    --arg arn "$CREATED_KNOWLEDGE_BASE_ARN" \
    '{knowledge_base_id: $id, knowledge_base_arn: $arn}' > "$OUTPUT_PATH"
}

# --- 메인 로직 ---
case "$ACTION" in
  create)
    # 기존 KB 삭제 로직은 create 흐름에 포함되어 있으므로 그대로 사용
    delete_knowledge_base
    create_knowledge_base
    ;;
  
  delete)
    delete_knowledge_base
    ;;

  *)
    echo "Error: Invalid action '$ACTION'. Use 'create' or 'delete'." >&2
    exit 1
    ;;
esac

echo "Action '$ACTION' completed successfully." >&2