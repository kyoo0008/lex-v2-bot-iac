# 로케일별 Assistant 생성
resource "awscc_wisdom_assistant" "locale_assistants" {
  for_each = toset(local.locales)

  name = "${local.wisdom_assistant_prefix}-${each.key}" # 예: qconnect-assistant-ko_KR
  type = "AGENT"
  server_side_encryption_configuration = {
    kms_key_id = data.aws_kms_key.example.arn
  }
  tags = [
    {
      key   = "AmazonConnectEnabled"
      value = "True"
    },
    {
      key   = "locale"
      value = "${each.key}"
    }
  ]

}

# # 로케일별 AI 기능(프롬프트, 에이전트) 관리자
resource "terraform_data" "wisdom_ai_manager" {
  for_each = awscc_wisdom_assistant.locale_assistants

  triggers_replace = [
    each.value,
    local.prompt_model_id,
    filemd5("${path.module}/scripts/manage_wisdom_ai.sh"),
    local.agent_name,
    local.agent_type,
    local.env,
    # env에 따라 트리거 소스를 변경
    md5(local.env == "dev" ? jsonencode(local.dev_prompts_list) : file("${path.module}/deployment_vars.json"))
  ]

  input = {
    assistant_id   = each.value.assistant_id
    model_id       = local.prompt_model_id
    region         = var.region
    # 각 로케일별로 고유한 에이전트 이름 부여
    agent_name     = "${local.agent_name}-${each.key}"
    locale         = each.key # for_each의 key가 로케일
    agent_type     = local.agent_type
    env            = local.env,
    
    # env에 따라 다른 프롬프트 정보를 JSON으로 전달
    prompts_json   = local.env == "dev" ? jsonencode(local.dev_prompts_list) : jsonencode(lookup(local.deployment_config, each.key, {prompts = []}).prompts)
    # prod 환경에서는 guardrail 정보도 전달 (예시)
    guardrails_json = local.env == "prod" ? jsonencode(lookup(local.deployment_config, each.key, {guardrails = []}).guardrails) : "[]"
  }

  provisioner "local-exec" {
    command = "chmod +x ${path.module}/scripts/manage_wisdom_ai.sh && ${path.module}/scripts/manage_wisdom_ai.sh"

    environment = {
      ASSISTANT_ID    = self.input.assistant_id
      MODEL_ID        = self.input.model_id
      REGION          = self.input.region
      AGENT_NAME      = self.input.agent_name
      LOCALE          = self.input.locale
      AGENT_TYPE      = self.input.agent_type
      ENV             = self.input.env
      PROMPTS_JSON    = self.input.prompts_json
      GUARDRAILS_JSON = self.input.guardrails_json
    }
  }

  depends_on = [
    data.local_file.prompts
  ]
}