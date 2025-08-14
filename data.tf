data "aws_connect_instance" "connect_instance" {
  instance_alias = var.connect_instance_alias
}

data "local_file" "prompt_txt" {
  filename = "${path.module}/prompts/prompt.txt"
}

resource "random_pet" "bucket_suffix" {
  length = 2
}
