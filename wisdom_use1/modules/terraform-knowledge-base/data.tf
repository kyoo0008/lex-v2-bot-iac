
# 2. 스크립트가 생성한 출력 파일을 읽어오는 데이터 소스
data "local_file" "kb_output" {
  filename = local.output_file_path

  # terraform_data 리소스가 실행된 후에 이 데이터 소스가 읽히도록 의존성 설정
  depends_on = [terraform_data.knowledge_base_manager]
}
