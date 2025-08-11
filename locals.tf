locals {
  # 압축할 최상위 소스 폴더 이름 정의
  lex_source_root_folder = "qic-test-bot-DRAFT-9BZCNEJHKK-LexJson"
  
  # 실제 파일 시스템에서의 전체 경로
  full_source_root_path = "${var.project_root_path}${local.lex_source_root_folder}"

  # 수정할 Intent.json의 상대 경로 (소스 폴더 기준)
  relative_intent_path = "qic-test-bot/BotLocales/en_US/Intents/AmazonQinConnect/Intent.json"
  
  # 수정할 파일의 전체 경로
  full_intent_path = "${local.full_source_root_path}/${local.relative_intent_path}"

  # 원본 JSON 파일 읽기 및 파싱
  original_intent_data = jsondecode(file(local.full_intent_path))
  
  # 동적으로 생성된 ARN으로 덮어쓸 부분 정의
  new_q_in_connect_config = {
    qInConnectIntentConfiguration = {
      qInConnectAssistantConfiguration = {
        assistantArn = awscc_wisdom_assistant.example.assistant_arn
      }
    }
  }
  kb_name = "example-knowledge-base-test"
  # 원본과 새로운 설정 병합
  modified_intent_data        = merge(local.original_intent_data, local.new_q_in_connect_config)
  modified_intent_json_string = jsonencode(local.modified_intent_data)

  # 파일 필터링 로직
  all_source_files        = fileset(local.full_source_root_path, "**/*")
  files_to_exclude        = toset(concat([local.relative_intent_path], [for f in local.all_source_files : f if endswith(f, ".DS_Store")]))
  unmodified_source_files = setsubtract(local.all_source_files, local.files_to_exclude)

  prompt_name = "example_text_completion_ai_prompt"
  prompt_model_id = "apac.amazon.nova-micro-v1:0"
}