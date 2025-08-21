locals {
  env = "dev"

  query_reformulation_prompt_name = "example_query_reformulation_prompt"
  prompt_model_id = "apac.amazon.nova-micro-v1:0" 

  # 4개의 로케일 정의
  # locales = ["en_US", "ko_KR", "zh_CN", "ja_JP"]
  locales = ["en_US", "ko_KR"]

  
  # To-do : agent_Type도 다중 처리 필요 
  # MANUAL_SEARCH,ANSWER_RECOMMENDATION,SELF_SERVICE  
  

  agent_configs = {
    # answer_recommendation = {
    #   agent_name = "answer_recommendation_agent"
    #   agent_type = "ANSWER_RECOMMENDATION"
    #   use_flag   = "false"
    # },
    # manual_search = {
    #   agent_name = "manual_search_agent"
    #   agent_type = "MANUAL_SEARCH"
    #   use_flag   = "false"
    # },
    self_service = {
      agent_name = "self_service_agent"
      agent_type = "SELF_SERVICE"
      use_flag   = "true"
    }  
  }

  # dev 환경에서 사용할 프롬프트 설정
  prompt_configs = {
    # answer_generation = {
    #   prompt_name_local = "example_answer_generation_prompt"
    #   prompt_file_data  = data.local_file.prompts["answer_generation"]
    #   prompt_type       = "ANSWER_GENERATION"
    #   prompt_api_format = "TEXT_COMPLETIONS"
    #   use_flag          = "false"
    # },
    # query_reformulation = {
    #   prompt_name_local = "example_query_reformulation_prompt"
    #   prompt_file_data  = data.local_file.prompts["query_reformulation"]
    #   prompt_type       = "QUERY_REFORMULATION"
    #   prompt_api_format = "MESSAGES"
    #   use_flag          = "false"
    # },
    # intent_labeling_generation = {
    #   prompt_name_local = "example_intent_labeling_generation_prompt"
    #   prompt_file_data  = data.local_file.prompts["intent_labeling_generation"]
    #   prompt_type       = "INTENT_LABELING_GENERATION"
    #   prompt_api_format = "MESSAGES"
    #   use_flag          = "false"
    # },
    self_service_pre_processing = {
      prompt_name_local = "example_self_service_pre_processing_prompt"
      prompt_file_data  = data.local_file.prompts["self_service_pre_processing"]
      prompt_type       = "SELF_SERVICE_PRE_PROCESSING"
      prompt_api_format = "MESSAGES"
      use_flag          = "true"
    },
    self_service_answer_generation = {
      prompt_name_local = "example_self_service_answer_generation_prompt"
      prompt_file_data  = data.local_file.prompts["self_service_answer_generation"]
      prompt_type       = "SELF_SERVICE_ANSWER_GENERATION"
      prompt_api_format = "TEXT_COMPLETIONS"
      use_flag          = "true"
    }
  }

  prompt_files = {
    # answer_generation              = "${path.module}/prompts/answer_generation_prompt.txt"
    # query_reformulation            = "${path.module}/prompts/query_reformulation_prompt.txt"
    # intent_labeling_generation     = "${path.module}/prompts/intent_labeling_generation_prompt.txt"
    self_service_pre_processing    = "${path.module}/prompts/self_service_pre_processing_prompt.txt"
    self_service_answer_generation = "${path.module}/prompts/self_service_answer_generation_prompt.txt"
  }

  # dev 환경용 프롬프트 JSON 리스트
  dev_prompts_list = [
    for key, config in local.prompt_configs : {
      prompt_name       = config.prompt_name_local
      prompt_content    = config.prompt_file_data.content
      prompt_type       = config.prompt_type
      prompt_api_format = config.prompt_api_format
      use_flag          = config.use_flag
    }
  ]

  # prod 환경일 경우, 배포 담당자가 생성한 설정 파일을 읽어옴
  deployment_config = local.env == "prod" ? jsondecode(file("${path.module}/deployment_vars.json")) : {}
  wisdom_assistant_prefix = "aicc-${local.env}-qconnect-assistant"
}