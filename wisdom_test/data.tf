data "aws_kms_key" "example" {
  key_id = "alias/amazon-q-in-connect-key"
}

data "local_file" "prompts" {
  for_each = local.prompt_files
  filename = each.value
}