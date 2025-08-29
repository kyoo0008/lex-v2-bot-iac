module "knowledge_bases" {
  for_each = awscc_wisdom_assistant.locale_assistants
  source   = "./modules/terraform-knowledge-base"

  # 모듈에 필요한 변수들을 전달합니다.
  assistant_arn       = each.value.assistant_arn
  knowledge_base_name = "${each.value.name}_kb"
  content_path        = "${local.content_path}/${each.key}"
  connect_instance_id = data.aws_connect_instance.connect_instance.id
  kms_key_id_arn      = data.aws_kms_key.example.arn
  region              = var.region
  locale              = each.key
  env                 = local.env

  depends_on = [
    data.aws_kms_key.example,
    awscc_wisdom_assistant.locale_assistants
  ]

}
