#!/bin/bash
set -e

echo "Connecting ReleaseAlias..."
aws connect associate-bot \
  --instance-id "$CONNECT_INSTANCE_ID" \
  --lex-v2-bot "{
    \"AliasArn\": \"$BOT_ALIAS_ARN\"
  }" \
  --region "$REGION"

if [ $? -eq 0 ]; then
  echo "ReleaseAlias connection completed successfully : $BOT_ALIAS_ARN"
else
  echo "Failed to connect ReleaseAlias : $BOT_ALIAS_ARN"
  exit 1
fi


