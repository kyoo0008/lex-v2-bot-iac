
# -----------------------------------------------------------------------------
# Manage Knowledge Base 
# -----------------------------------------------------------------------------
# resource "terraform_data" "wisdom_knowledge_base" {

#   triggers_replace = [
#     awscc_wisdom_assistant.example,
#     local.knowledge_base_name,
#     local.knowledge_base_model_id
#   ]

#   input = {
#     assistant_id   = awscc_wisdom_assistant.example.assistant_id
#     model_id       = local.knowledge_base_model_id
#     region         = var.region
#     knowledge_base_name    = local.knowledge_base_name
#   }

#   provisioner "local-exec" {
#     command = "chmod +x ${path.module}/scripts/manage_knowledge_base.sh && ${path.module}/scripts/manage_knowledge_base.sh create"
    
#     # 스크립트에 환경 변수로 값 전달
#     environment = {
#       ASSISTANT_ID   = self.input.assistant_id
#       MODEL_ID       = self.input.model_id
#       REGION         = self.input.region
#       KNOWLEDGE_BASE_CONTENT = self.input.knowledge_base_content
#       KNOWLEDGE_BASE_NAME    = self.input.knowledge_base_name
#     }
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = "chmod +x ${path.module}/scripts/manage_knowledge_base.sh && ${path.module}/scripts/manage_knowledge_base.sh delete"
    
#     environment = {
#       ASSISTANT_ID   = self.input.assistant_id
#       MODEL_ID       = self.input.model_id
#       REGION         = self.input.region
#       KNOWLEDGE_BASE_CONTENT = self.input.knowledge_base_content
#       KNOWLEDGE_BASE_NAME    = self.input.knowledge_base_name
#     }
#   }
# }

# -----------------------------------------------------------------------------
# Manage Assistant <-> KnowledgeBase Association
# -----------------------------------------------------------------------------
resource "terraform_data" "association_manager" {
  triggers_replace = [
    awscc_wisdom_assistant.example,
    awscc_wisdom_knowledge_base.example,
    data.aws_connect_instance.connect_instance.id
  ]

  input = {
    connect_instance_id = data.aws_connect_instance.connect_instance.id
    assistant_arn       = awscc_wisdom_assistant.example.assistant_arn
    kb_arn              = awscc_wisdom_knowledge_base.example.knowledge_base_arn
  }

  # 생성 및 업데이트 프로비저너
  provisioner "local-exec" {
    command = "chmod +x ${path.module}/scripts/manage_association.sh && ${path.module}/scripts/manage_association.sh create"
    
    # 스크립트에 필요한 변수를 환경 변수로 전달
    environment = {
      CONNECT_INSTANCE_ID = self.input.connect_instance_id
      ASSISTANT_ARN       = self.input.assistant_arn
      KB_ARN              = self.input.kb_arn
    }
  }

  # 삭제 프로비저너
  provisioner "local-exec" {
    when    = destroy
    command = "chmod +x ${path.module}/scripts/manage_association.sh && ${path.module}/scripts/manage_association.sh delete" 
    
    environment = {
      CONNECT_INSTANCE_ID = self.input.connect_instance_id
      ASSISTANT_ARN       = self.input.assistant_arn
      KB_ARN              = self.input.kb_arn
    }
  }
}
