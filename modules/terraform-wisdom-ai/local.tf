locals {

  env = var.env

  output_file_path = "${path.module}/.wisdom_ai_output_${var.locale}.json"
  wisdom_ai_result = fileexists(local.output_file_path) ? jsondecode(data.local_file.wisdom_ai_output.content) : {}

  agent_configs = {
    self_service = {
      agent_name = "self_service_agent"
      agent_type = "SELF_SERVICE"
      use_flag   = "true"
    }  
  }

  prompt_configs = {
    self_service_pre_processing = {
      prompt_name_local = "example_self_service_pre_processing_prompt"
      prompt_type       = "SELF_SERVICE_PRE_PROCESSING"
      prompt_api_format = "MESSAGES"
      prompt_content    = var.self_service_pre_processing_prompt_content
      use_flag          = "true"
    },
    self_service_answer_generation = {
      prompt_name_local = "example_self_service_answer_generation_prompt"
      prompt_type       = "SELF_SERVICE_ANSWER_GENERATION"
      prompt_api_format = "TEXT_COMPLETIONS"
      prompt_content    = var.self_service_answer_generation_prompt_content
      use_flag          = "true"
    }
  }

  # prompt_file_basenames = {
  #   self_service_pre_processing    = "self_service_pre_processing_prompt.txt"
  #   self_service_answer_generation = "self_service_answer_generation_prompt.txt"
  # }

  # locale_prompt_files_map = {
  #   for item in flatten([
  #     for locale in local.locales : [
  #       for key, basename in local.prompt_file_basenames : {
  #         map_key  = "${locale}.${key}"
  #         filename = "${path.module}/prompts/${locale}/${basename}"
  #       }
  #     ]
  #   ]) : item.map_key => item.filename
  # }


  # prod 환경일 경우, 배포 담당자가 생성한 설정 파일을 읽어옴
  deployment_config = local.env == "prod" ? jsondecode(file("${path.module}/deployment_vars.json")) : {}
  wisdom_assistant_prefix = "aicc-${local.env}-qconnect-assistant"

}

