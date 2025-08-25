resource "terraform_data" "connect_bot_association" {


  triggers_replace = [
    awscc_lex_bot_version.bot_new_version
    # timestamp()
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      CONNECTED_BOT_JSON_ENCODED="${var.connected_bots}"
      RELEASE_ALIAS_ARN="arn:aws:lex:${var.region}:${var.account_id}:bot-alias/${aws_lexv2models_bot.bot.id}/${data.external.release_alias_id.result.bot_alias_id}"

      if [ "${var.env}" == "dev" ]; then
        BASE_ARN=$(echo "$RELEASE_ALIAS_ARN" | sed -E 's|^(.*bot-alias/[^/]+/).*|\1|')
        TEST_ALIAS_ARN="$BASE_ARN"TSTALIASID
      else
        TEST_ALIAS_ARN=""
      fi

      # Function to check if an ARN exists in the JSON encoded list
      check_arn_exists() {
        local arn_to_check="$1"
        if echo "$CONNECTED_BOT_JSON_ENCODED" | jq -e --arg arn "$arn_to_check" '.[] | .AliasArn == $arn' > /dev/null; then
          return 0 # Found
        else
          return 1 # Not found
        fi
      }

      # Check if ReleaseAlias needs to be connected
      if check_arn_exists "$RELEASE_ALIAS_ARN"; then
        echo "ReleaseAlias is already connected"
      else
        echo "Connecting ReleaseAlias..."
        aws connect associate-bot \
          --instance-id "${data.aws_connect_instance.this[0].id}" \
          --lex-v2-bot "{
            \"AliasArn\": \"$RELEASE_ALIAS_ARN\"
          }" \
          --region "${var.region}"

        if [ $? -eq 0 ]; then
          echo "ReleaseAlias connection completed successfully"
        else
          echo "Failed to connect ReleaseAlias"
          exit 1
        fi
      fi

      # Process TestBotAlias if it exists and is not null
      if [ ! -z "$TEST_ALIAS_ARN" ] && [ "$TEST_ALIAS_ARN" != "null" ]; then
        if check_arn_exists "$TEST_ALIAS_ARN"; then
          echo "TestBotAlias is already connected"
        else
          echo "Connecting TestBotAlias..."
          aws connect associate-bot \
            --instance-id "${data.aws_connect_instance.this[0].id}" \
            --lex-v2-bot "{
              \"AliasArn\": \"$TEST_ALIAS_ARN\"
            }" \
            --region "${var.region}"

          if [ $? -eq 0 ]; then
            echo "TestBotAlias connection completed successfully"
          else
            echo "Failed to connect TestBotAlias"
            exit 1
          fi
        fi
      fi
    EOT
  }

  depends_on = [
    aws_lexv2models_bot.bot,
    data.external.release_alias_id,
    aws_lexv2models_bot_version.bot_new_version,
    terraform_data.deploy_to_release_alias
  ]
}
