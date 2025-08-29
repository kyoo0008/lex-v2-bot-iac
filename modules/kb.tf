# ./kb.tf

module "knowledge_base" {
  source   = "./terraform-knowledge-base"

  # 모듈에 필요한 변수들을 전달합니다.
  assistant_arn       = "arn:aws:wisdom:ap-northeast-2:009160043124:assistant/73a08860-5a94-44eb-ab6b-ba968488fe5f"
  knowledge_base_name = "test_kb"
  content_path        = "contents/"
  connect_instance_id = "e8c94677-9e87-4078-b7b2-4b517d191080"
  kms_key_id_arn      = "arn:aws:kms:ap-northeast-2:009160043124:key/fc768b6b-31f3-4f23-b16e-ae6af935f8c4"
  region              = "ap-northeast-2"

}

output "kb_result" {
  value = module.knowledge_base
}
# kb_result = {
#   "knowledge_base_arn" = "arn"
#   "knowledge_base_id" = "id"
# }