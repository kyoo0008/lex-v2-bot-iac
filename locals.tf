locals {
  # 압축할 최상위 소스 폴더 이름 정의
  lex_source_root_folder = "qic-test-bot-DRAFT-9BZCNEJHKK-LexJson"
  lex_bot_name = "qic-test-bot"
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

  

  # 다중 locale 처리 필요
  agent_name = "example_ai_agent_test"
   #[en_US, en_GB, en_AU, en_NZ, en_IE, en_ZA, en_IN, en_CY, en_SG, es_ES, es_MX, es_US, fr_FR, fr_BE, fr_CA, de_DE, de_AT, de_CH, it_IT, pt_BR, pt_PT, ca_ES, zh_HK, zh_CN, ja_JP, ko_KR, ar_AE, ar, nl_BE, nl_NL, fi_FI, da_DK, no_NO, sv_SE, is_IS, hi_IN, pl_PL, ro_RO, ru_RU, cs_CZ, sk_SK, hu_HU, sr_RS, lt_LT, lv_LV, et_EE, sl_SI, bg_BG, cy_GB, id_ID, th_TH, ms_MY, tl_PH, vi_VN, km_KH, hmn, lo_LA, zu_ZA, xh_ZA, af_ZA, fa_IR, he_IL, ga_IE, hy_AM, tr_TR]
  locale = "en_US" 
  agent_type = "ANSWER_RECOMMENDATION"



  content_path = "${path.module}/QiCContent"

  answer_generation_prompt_name = "example_answer_generation_prompt"
  query_reformulation_prompt_name = "example_query_reformulation_prompt"
  prompt_model_id = "apac.amazon.nova-micro-v1:0" 
}