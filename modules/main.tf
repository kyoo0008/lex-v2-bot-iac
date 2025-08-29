data "local_file" "self_service_pre_processing_prompt_content" {
  # for_each
  filename = "self_service_pre_processing_prompt.txt"
}

data "local_file" "self_service_answer_generation_prompt_content" {
  # for_each
  filename = "self_service_answer_generation_prompt.txt"
}

module "wisdom_ai_agents" {
  # for_each = awscc_wisdom_assistant.locale_assistants

  # source "./modules/terraform-wisdom-ai"
  source = "./terraform-wisdom-ai"
  locale = "en_US" # [each.key]
  env = "dev" # local.env
  region = "ap-northeast-2" # var.region
  prompt_model_id = "apac.amazon.nova-micro-v1:0" # local.prompt_model_id

  # 모듈에 필요한 변수들을 전달합니다.
  assistant_arn       = "arn:aws:wisdom:ap-northeast-2:009160043124:assistant/73a08860-5a94-44eb-ab6b-ba968488fe5f"

  connect_instance_id = "e8c94677-9e87-4078-b7b2-4b517d191080"
  self_service_pre_processing_prompt_content = data.local_file.self_service_pre_processing_prompt_content.content
  self_service_answer_generation_prompt_content = data.local_file.self_service_answer_generation_prompt_content.content
  
}

output "result" {
  value = module.wisdom_ai_agents
}