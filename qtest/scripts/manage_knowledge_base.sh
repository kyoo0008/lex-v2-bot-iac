#!/bin/bash
set -e # 스크립트 실행 중 오류가 발생하면 즉시 중단

# --- 입력 파라미터 ---
ACTION="$1"

# 환경 변수에서 값들을 가져옵니다.
if [ -z "$KMS_KEY_ID_ARN" ] || [ -z "$APP_INTEGRATION_ARN" ] || [ -z "$KNOWLEDGE_BASE_NAME" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi

# --- 공통 함수: 지식기반 삭제 ---
delete_knowledge_base() {
  echo "Searching for existing KnowledgeBase named '$KNOWLEDGE_BASE_NAME'..."
  
  KNOWLEDGE_BASE_JSON=$(aws qconnect list-knowledge-bases \
    --query "knowledgeBaseSummaries[?name=='$KNOWLEDGE_BASE_NAME']" \
    --output json)

  if [ "$(echo "$KNOWLEDGE_BASE_JSON" | jq 'length')" -gt 0 ]; then
    echo "$KNOWLEDGE_BASE_JSON" | jq -r '.[].knowledgeBaseId' | while read -r KNOWLEDGE_BASE_ID; do
      echo "Deleting KnowledgeBase ID: $KNOWLEDGE_BASE_ID"
      aws qconnect delete-knowledge-base \
        --knowledge-base-id "$KNOWLEDGE_BASE_ID"
      sleep 1
    done
  else
    echo "KnowledgeBase not found, skipping deletion."
  fi
}

# --- 공통 함수: 지식기반 생성 및 콘텐츠 재귀적 업로드 ---
create_knowledge_base() {
  echo "Creating new KnowledgeBase '$KNOWLEDGE_BASE_NAME'..."

  # 입력용 JSON 생성: CUSTOM 타입
  INPUT_JSON=$(jq -n \
    --arg knowledgeBaseName "$KNOWLEDGE_BASE_NAME" \
    --arg kmsKeyIdArn "$KMS_KEY_ID_ARN" \
    '{
      "name": $knowledgeBaseName,
      "knowledgeBaseType": "CUSTOM",
      "serverSideEncryptionConfiguration": {
        "kmsKeyId": $kmsKeyIdArn
      },
      "tags": {
        "AmazonConnectEnabled": "True"
      }
    }')
  
  # 지식기반 생성 API 호출
  CREATED_KNOWLEDGE_BASE_ID=$(aws qconnect create-knowledge-base \
    --region "$REGION" \
    --cli-input-json "$INPUT_JSON" \
    --output json | jq -r '.knowledgeBase.knowledgeBaseId')

  echo "KnowledgeBase created (ID: $CREATED_KNOWLEDGE_BASE_ID). Starting recursive content upload from 'QiCContent' directory..."

  CONTENT_DIR="../QiCContent" # 경로 수정
  if [ ! -d "$CONTENT_DIR" ]; then
      echo "Error: Content directory not found at $CONTENT_DIR"
      exit 1
  fi

  find "$CONTENT_DIR" -type f \( -name "*.docx" -o -name "*.txt" \) | while read -r FILE_PATH; do
    echo "--------------------------------------------------"
    echo "Processing file: $FILE_PATH"

    CONTENT_TYPE=""
    if [[ "$FILE_PATH" == *.docx ]]; then
      CONTENT_TYPE="application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    elif [[ "$FILE_PATH" == *.txt ]]; then
      CONTENT_TYPE="text/plain"
    else
      echo "Skipping unsupported file type: $FILE_PATH"
      continue
    fi
    echo "Content-Type: $CONTENT_TYPE"

    CONTENT_NAME=$(basename "$FILE_PATH")

    echo "Starting upload for '$CONTENT_NAME'..."
    UPLOAD_INFO_JSON=$(aws qconnect start-content-upload \
      --knowledge-base-id "$CREATED_KNOWLEDGE_BASE_ID" \
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
      --knowledge-base-id "$CREATED_KNOWLEDGE_BASE_ID" \
      --name "$CONTENT_NAME" \
      --upload-id "$UPLOAD_ID" > /dev/null

    echo "Successfully uploaded '$CONTENT_NAME'."
  done

  echo "--------------------------------------------------"
  echo "All files have been processed."
}


# --- 메인 로직 ---
case "$ACTION" in
  create)
    delete_knowledge_base
    create_knowledge_base
    ;;
  
  delete)
    delete_knowledge_base
    ;;

  *)
    echo "Error: Invalid action '$ACTION'. Use 'create' or 'delete'."
    exit 1
    ;;
esac

echo "Action '$ACTION' completed successfully."