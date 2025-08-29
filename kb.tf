module "knowledge_base" {
  for_each = awscc_wisdom_assistant.locale_assistants
  source   = "./modules/terraform-knowledge-base"

  # 모듈에 필요한 변수들을 전달합니다.
  assistant_arn       = each.value.assistant_arn
  knowledge_base_name = "${each.value.name}_kb"
  content_path        = "${local.content_path}/${each.key}"
  connect_instance_id = data.aws_connect_instance.connect_instance.id
  kms_key_id_arn      = data.aws_kms_key.example.arn
  region              = var.region

  depends_on = [
    data.aws_kms_key.example,
    awscc_wisdom_assistant.locale_assistants
  ]

}
# To-do : knowledge_base_manager delete logic에 kb content 삭제 관리도 추가하기 
# To-do : kb module을 따로 만들어서 output으로 다른 자원에 할당 되도록 구성?
# To-do : destroy에서 connect delete integration associate 로직 추가 
# -----------------------------------------------------------------------------
# Manage Knowledge Base 
# -----------------------------------------------------------------------------
# resource "terraform_data" "knowledge_base_manager" {
#   for_each = awscc_wisdom_assistant.locale_assistants

#   triggers_replace = [
#     each.value,
#     data.aws_kms_key.example,
#     local.content_path,
#     sha1(join("", [for f in fileset("${local.content_path}/${each.key}", "*"): filesha1("${local.content_path}/${each.key}/${f}")])),
#     filemd5("${path.module}/scripts/manage_knowledge_base.sh"),
#   ]

#   input = {
#     assistant_arn   = each.value.assistant_arn
#     region         = var.region
#     knowledge_base_name    = "${each.value.name}_kb"
#     kms_key_id_arn   = data.aws_kms_key.example.arn
#     content_path = "${local.content_path}/${each.key}"
#     connect_instance_id = data.aws_connect_instance.connect_instance.id
#   }

#   provisioner "local-exec" {
#     command = "chmod +x ${path.module}/scripts/manage_knowledge_base.sh && ${path.module}/scripts/manage_knowledge_base.sh create"
    
#     # 스크립트에 환경 변수로 값 전달
#     environment = {
#       KMS_KEY_ID_ARN = self.input.kms_key_id_arn
#       REGION         = self.input.region
#       KNOWLEDGE_BASE_NAME    = self.input.knowledge_base_name
#       CONTENT_PATH = self.input.content_path
#       ASSISTANT_ARN = self.input.assistant_arn
#       CONNECT_INSTANCE_ID = self.input.connect_instance_id
#     }
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = "chmod +x ${path.module}/scripts/manage_knowledge_base.sh && ${path.module}/scripts/manage_knowledge_base.sh delete"
    
#     environment = {
#       KMS_KEY_ID_ARN = self.input.kms_key_id_arn
#       REGION         = self.input.region
#       KNOWLEDGE_BASE_NAME    = self.input.knowledge_base_name
#       CONTENT_PATH = self.input.content_path
#       ASSISTANT_ARN = self.input.assistant_arn
#       CONNECT_INSTANCE_ID = self.input.connect_instance_id
#     }
#   }

#   depends_on = [
#     data.aws_kms_key.example,
#     awscc_wisdom_assistant.locale_assistants
#   ]
# }

# -----------------------------------------------------------------------------
# Manage Assistant Association
# -----------------------------------------------------------------------------
# resource "terraform_data" "assistant_association_manager" {
#   triggers_replace = [
#     awscc_wisdom_assistant.example,
#     data.aws_connect_instance.connect_instance.id
#   ]

#   input = {
#     connect_instance_id = data.aws_connect_instance.connect_instance.id
#     assistant_arn       = awscc_wisdom_assistant.example.assistant_arn
#     kb_name              = local.kb_name
#   }

#   # 생성 및 업데이트 프로비저너
#   provisioner "local-exec" {
#     command = "chmod +x ${path.module}/scripts/manage_association.sh && ${path.module}/scripts/manage_association.sh create"
    
#     # 스크립트에 필요한 변수를 환경 변수로 전달
#     environment = {
#       CONNECT_INSTANCE_ID = self.input.connect_instance_id
#       ASSISTANT_ARN       = self.input.assistant_arn
#       KB_NAME              = self.input.kb_name
#     }
#   }

#   # 삭제 프로비저너
#   provisioner "local-exec" {
#     when    = destroy
#     command = "chmod +x ${path.module}/scripts/manage_association.sh && ${path.module}/scripts/manage_association.sh delete" 
    
#     environment = {
#       CONNECT_INSTANCE_ID = self.input.connect_instance_id
#       ASSISTANT_ARN       = self.input.assistant_arn
#       KB_NAME              = self.input.kb_name
#     }
#   }

#   depends_on = [
#     terraform_data.knowledge_base_manager
#   ]
# }
