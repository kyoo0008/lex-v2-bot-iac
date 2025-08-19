data "aws_connect_instance" "connect_instance" {
  instance_alias = var.connect_instance_alias
}

data "local_file" "answer_generation_prompt_txt" {
  filename = "${path.module}/prompts/answer_generation_prompt.txt"
}
data "local_file" "query_reformulation_prompt_txt" {
  filename = "${path.module}/prompts/query_reformulation_prompt.txt"
}


resource "random_pet" "bucket_suffix" {
  length = 2
}
