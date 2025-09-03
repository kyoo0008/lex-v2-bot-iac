# 1. 특정 값이 변경될 때만 스크립트를 실행하는 리소스
resource "terraform_data" "knowledge_base_manager" {
  # 이 값들이 변경될 때만 리소스가 재생성(destroy and create)됩니다.
  triggers_replace = {
    # 스크립트 파일 내용이 변경될 때
    script_hash = filemd5("${path.module}/scripts/manage_knowledge_base.sh")
    # 콘텐츠 파일들이 변경될 때
    content_hash = sha1(join("", [
      for f in fileset(var.content_path, "**/*") : filesha1("${var.content_path}/${f}")
    ]))
    # 기타 중요한 변수들
    knowledge_base_name = var.knowledge_base_name
    assistant_arn       = var.assistant_arn
    output_path         = local.output_file_path
  }

  input = {
    kms_key_id_arn = var.kms_key_id_arn
    content_path = var.content_path
    knowledge_base_name = var.knowledge_base_name
    assistant_arn = var.assistant_arn
    connect_instance_id = var.connect_instance_id
    region = var.region
    output_file_path = local.output_file_path
  }

  # 생성(create) 시에 실행되는 프로비저너
  provisioner "local-exec" {
    # 스크립트에 'create' 액션과 출력 파일 경로를 인자로 전달
    command = "${path.module}/scripts/manage_knowledge_base.sh create"
    
    # 스크립트는 이제 환경 변수에서 입력을 읽습니다.
    environment = {
      KMS_KEY_ID_ARN      = self.input.kms_key_id_arn
      CONTENT_PATH        = self.input.content_path
      KNOWLEDGE_BASE_NAME = self.input.knowledge_base_name
      ASSISTANT_ARN       = self.input.assistant_arn
      CONNECT_INSTANCE_ID = self.input.connect_instance_id
      REGION              = self.input.region
      OUTPUT_PATH         = self.input.output_file_path
    }
  }

  # 삭제(destroy) 시에 실행되는 프로비저너
  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/manage_knowledge_base.sh delete"
    
    environment = {
      KMS_KEY_ID_ARN      = self.input.kms_key_id_arn
      CONTENT_PATH        = self.input.content_path
      KNOWLEDGE_BASE_NAME = self.input.knowledge_base_name
      ASSISTANT_ARN       = self.input.assistant_arn
      CONNECT_INSTANCE_ID = self.input.connect_instance_id
      REGION              = self.input.region
      OUTPUT_PATH         = self.input.output_file_path
    }
  }
}
