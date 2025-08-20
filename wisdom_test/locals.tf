locals {
  env = "dev"
  answer_generation_prompt_name = "example_answer_generation_prompt"
  query_reformulation_prompt_name = "example_query_reformulation_prompt"
  prompt_model_id = "apac.amazon.nova-micro-v1:0" 

  # 4개의 로케일 정의
  # locales = ["en_US", "ko_KR", "zh_CN", "ja_JP"]
  locales = ["en_US", "ko_KR"]

  # To-do : agent_Type도 다중 처리 필요 
  agent_type = "ANSWER_RECOMMENDATION"
  # dev 환경에서 사용할 프롬프트 설정 (기존과 동일)
  prompt_configs = {
    answer_generation = {
      prompt_name_local = local.answer_generation_prompt_name
      prompt_file_data  = data.local_file.prompts["answer_generation"]
      prompt_type       = "ANSWER_GENERATION"
    },
    query_reformulation = {
      prompt_name_local = local.query_reformulation_prompt_name
      prompt_file_data  = data.local_file.prompts["query_reformulation"]
      prompt_type       = "QUERY_REFORMULATION"
    }
  }

  prompt_files = {
    answer_generation   = "${path.module}/prompts/answer_generation_prompt.txt"
    query_reformulation = "${path.module}/prompts/query_reformulation_prompt.txt"
  }

  # dev 환경용 프롬프트 JSON 리스트
  dev_prompts_list = [
    for key, config in local.prompt_configs : {
      prompt_name    = config.prompt_name_local
      prompt_content = config.prompt_file_data.content
      prompt_type    = config.prompt_type
    }
  ]

  # prod 환경일 경우, 배포 담당자가 생성한 설정 파일을 읽어옴
  deployment_config = local.env == "prod" ? jsondecode(file("${path.module}/deployment_vars.json")) : {}
  wisdom_assistant_prefix = "aicc-${local.env}-qconnect-assistant"
}