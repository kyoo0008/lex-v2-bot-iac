# ISSUE : "visibilityStatus": "PUBLISHED" 옵션이 현재 없어서 awscc_wisdom_ai(agent, prompt, guardrail)로 update 하지 못함 
# Assistant는 한 connect당 하나씩만 할당 가능 -> 사실상 여러명이서 테스트하기는 곤란할듯?
# To-do : agent tags 에 ready_version : n 으로 release 할 버전 할당하기 
# To-do : update-assistant-ai-agent(콘솔상에서 assistant default를 setting하는 기능) -> 하나의 assistant당 하나의 locale만 가능한듯 
# wisdom ai 자원들은 version 관리가 들어가므로 when = destroy는 뺀다(삭제 후 생성하면 버전관리가 안됨), delete_flag=true or false로 관리 
# env : dev일 경우  
#   1. 사용자가 prompt, guardrail 개발, 개발 시에는 prompt,guardrail,agent 각각 version을 바꿔가며 할 수 있음.
#   2. 개발 완료 후 prompt,guardrail,agent 각각 version 생성 or 해당 version에서 Publish
#   3. Publish한 버전을 태그에 ready_version: versionNumber(1,2,3..)을 달기, 이후 ready_version에서는 수정 X, 수정이 하고 싶다면 새로운 버전을 생성하여 할 것
#   4. 배포담당자는 스크립트로 ready_version의 agent, prompt, guardrail 정보를 local repository에 저장(prompt 경로는 locals.prompt_files에 있음)
#   5. 
# env : stg, prd일 경우
#   1. prompt, guardrail를 repo의 정보로 INPUT_JSON을 만들어 create version
#   2. agent를 create한 prompt, guardrail을 기반으로 create version
#   3. update-assistant-ai-agent로 set default 해주기 
resource "terraform_data" "wisdom_ai_manager" { 

  triggers_replace = [
    awscc_wisdom_assistant.example,
    local.prompt_model_id,
    filemd5("${path.module}/scripts/manage_wisdom_ai.sh"),
    local.delete_flag,
    local.agent_name,
    local.locale,
    local.agent_type,
    local.env,
    # 프롬프트 리스트의 내용이 변경되면 리소스를 재생성하도록 md5 해시를 사용
    md5(jsonencode(local.prompt_configs_list))
  ]

  input = {
    assistant_id   = awscc_wisdom_assistant.example.assistant_id
    model_id       = local.prompt_model_id
    region         = var.region
    agent_name     = local.agent_name
    locale         = local.locale
    agent_type     = local.agent_type
    delete_flag    = local.delete_flag,
    prompts_json   = jsonencode(local.prompt_configs_list)
    env            = local.env
  }

  provisioner "local-exec" {
    command = "chmod +x ${path.module}/scripts/manage_wisdom_ai.sh && ${path.module}/scripts/manage_wisdom_ai.sh"

    # 스크립트에 전달할 환경 변수 수정
    environment = {
      ASSISTANT_ID   = self.input.assistant_id
      MODEL_ID       = self.input.model_id
      REGION         = self.input.region
      AGENT_NAME     = self.input.agent_name
      LOCALE         = self.input.locale
      AGENT_TYPE     = self.input.agent_type
      DELETE_FLAG    = self.input.delete_flag
      PROMPTS_JSON   = self.input.prompts_json
      ENV            = self.input.env
    }
  }

  depends_on = [
    awscc_wisdom_assistant.example,
    data.local_file.prompts # prompt 파일들을 먼저 읽도록 의존성 추가
  ]
}