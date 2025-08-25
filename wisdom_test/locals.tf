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
      prompt_type       = "SELF_SERVICE_PRE_PROCESSING"
      prompt_api_format = "MESSAGES"
      use_flag          = "true"
    },
    self_service_answer_generation = {
      prompt_name_local = "example_self_service_answer_generation_prompt"
      prompt_type       = "SELF_SERVICE_ANSWER_GENERATION"
      prompt_api_format = "TEXT_COMPLETIONS"
      use_flag          = "true"
    }
  }

  prompt_file_basenames = {
    self_service_pre_processing    = "self_service_pre_processing_prompt.txt"
    self_service_answer_generation = "self_service_answer_generation_prompt.txt"
  }

  locale_prompt_files_map = {
    for item in flatten([
      for locale in local.locales : [
        for key, basename in local.prompt_file_basenames : {
          map_key  = "${locale}.${key}"
          filename = "${path.module}/prompts/${locale}/${basename}"
        }
      ]
    ]) : item.map_key => item.filename
  }


  # prod 환경일 경우, 배포 담당자가 생성한 설정 파일을 읽어옴
  deployment_config = local.env == "prod" ? jsondecode(file("${path.module}/deployment_vars.json")) : {}
  wisdom_assistant_prefix = "aicc-${local.env}-qconnect-assistant"

  lex_bot_log_group_name = "/aws/lex/QicBot" 


  content_path = "${path.module}/QiCContent"
  
  qic_create_session = {
    name = "qic-create-sessions-func"
    desc = "QiC Create Session by Locale ID, Contact ID"
  }

  lex_hook_func = {
    name = "lex-hook-func"
    desc = "Lex Hook Function"
  }
  boundary = "qic-test-boundary"
  

  ##########################################################################################
  # LEX
  ##########################################################################################
  # 압축할 최상위 소스 폴더 이름 정의
  lex_source_root_folder = "qic-bot"
  lex_bot_name           = "qic-test-bot"
  # 실제 파일 시스템에서의 전체 경로
  full_source_root_path = "${var.project_root_path}${local.lex_source_root_folder}"

  # 동적으로 생성된 ARN으로 덮어쓸 부분 정의
  # new_q_in_connect_config = {
  #   qInConnectIntentConfiguration = {
  #     qInConnectAssistantConfiguration = {
  #       assistantArn = awscc_wisdom_assistant.example.assistant_arn
  #     }
  #   }
  # }

  intent_data_by_locale = {
    for locale in local.locales : locale => {
      # 1. 각 로케일별 Intent 파일의 상대 경로를 정의
      relative_path = "${local.lex_bot_name}/BotLocales/${locale}/Intents/AmazonQinConnect/Intent.json"

      # 2. 수정된 최종 JSON 문자열을 생성
      # 모든 계산을 jsonencode 함수 내에서 한 번에 처리하여 순환 참조를 방지합니다.
      modified_json_string = jsonencode(merge(
        # 2a. 원본 JSON 파일을 읽고 파싱
        jsondecode(file("${local.full_source_root_path}/${local.lex_bot_name}/BotLocales/${locale}/Intents/AmazonQinConnect/Intent.json")),
        # 2b. 삽입할 새로운 설정을 정의 (Wisdom Assistant ARN을 동적으로 참조)
        {
          qInConnectIntentConfiguration = {
            qInConnectAssistantConfiguration = {
              assistantArn = awscc_wisdom_assistant.locale_assistants[locale].assistant_arn
            }
          }
        }
      ))
    }
  }

  # 파일 필터링 로직
  all_source_files = fileset(local.full_source_root_path, "**/*")
  
  # [수정됨] 제외할 파일 목록에 모든 로케일의 Intent 경로를 동적으로 추가
  files_to_exclude = toset(concat(
    [for data in local.intent_data_by_locale : data.relative_path],
    [for f in local.all_source_files : f if endswith(f, ".DS_Store")]
  ))
  
  unmodified_source_files = setsubtract(local.all_source_files, local.files_to_exclude)
  
}