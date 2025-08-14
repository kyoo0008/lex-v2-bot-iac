

# -----------------------------------------------------------------------------
# association delete, create 로직
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
    command = "chmod +x ${path.module}/manage_association.sh && ${path.module}/manage_association.sh create"
    
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
    command = "${path.module}/manage_association.sh delete" 
    
    environment = {
      CONNECT_INSTANCE_ID = self.input.connect_instance_id
      ASSISTANT_ARN       = self.input.assistant_arn
      KB_ARN              = self.input.kb_arn
    }
  }
}

resource "aws_s3_object" "folder_upload" {
  # for_each = fileset("${path.module}/QiCContent", "**/*")
  for_each = {
    for file in fileset("${path.module}/QiCContent", "**/*") : file => file
    if !can(regex(".*\\.DS_Store$", file)) # Example: ignore files ending with .ignore
  }


  bucket = aws_s3_bucket.qic_kb_bucket.id
  key    = each.value
  source = "${path.module}/QiCContent/${each.value}"

  source_hash = filemd5("${path.module}/QiCContent/${each.value}")

  # lifecycle {
  #   ignore_changes = [
  #     tags
  #   ]
  # }
}
