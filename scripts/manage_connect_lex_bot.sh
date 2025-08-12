set -e

      BOT_NAME="${each.value.bot_name}"
      BOT_ID="${each.value.bot_id}"
      RELEASE_ALIAS_ARN="${each.value.alias_arn}"
      # TEST_ALIAS_ARN="${each.value.test_alias_arn != null ? each.value.test_alias_arn : ""}"
      INSTANCE_ID="${data.aws_connect_instance.connect_instance.id}"
      REGION="${var.region}"

      echo "Checking connected bots for $BOT_NAME..."

      # Get connected bots for the current bot_id
      CONNECTED_BOTS=$(aws connect list-bots \
        --instance-id "$INSTANCE_ID" \
        --lex-version "V2" \
        --region "$REGION" \
        --query "LexBots[?contains(LexV2Bot.AliasArn, '$BOT_ID')].LexV2Bot.AliasArn" \
        --output json)

      echo "Connected bots: $CONNECTED_BOTS"

      # Function to associate a bot alias
      associate_bot_alias() {
        ALIAS_ARN="$1"
        ALIAS_TYPE="$2"

        if echo "$CONNECTED_BOTS" | jq -e --arg arn "$ALIAS_ARN" 'contains([$arn])' > /dev/null; then
          echo "$ALIAS_TYPE Alias is already connected for $BOT_NAME"
        else
          echo "Connecting $ALIAS_TYPE Alias for $BOT_NAME..."
          aws connect associate-bot \
            --instance-id "$INSTANCE_ID" \
            --lex-v2-bot "{
              \"AliasArn\": \"$ALIAS_ARN\"
            }" \
            --region "$REGION"

          if [ $? -eq 0 ]; then
            echo "$ALIAS_TYPE Alias connection completed successfully for $BOT_NAME"
          else
            echo "Failed to connect $ALIAS_TYPE Alias for $BOT_NAME"
            exit 1
          fi
          sleep 5 # Wait to avoid quota issues
        fi
      }

      associate_bot_alias "$RELEASE_ALIAS_ARN" "Release"

      if [ ! -z "$TEST_ALIAS_ARN" ] && [ "$TEST_ALIAS_ARN" != "null" ]; then
        # associate_bot_alias "$TEST_ALIAS_ARN" "Test"
      fi
