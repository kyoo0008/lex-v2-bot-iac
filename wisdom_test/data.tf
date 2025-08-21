data "aws_kms_key" "example" {
  key_id = "alias/amazon-q-in-connect-key"
}


data "local_file" "prompts" {
  for_each = local.locale_prompt_files_map
  filename = each.value
}

data "aws_connect_instance" "connect_instance" {
  instance_alias = var.connect_instance_alias
}
