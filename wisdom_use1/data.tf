data "aws_kms_key" "example" {
  key_id = "alias/QiCBetaKMSKey"
}


data "local_file" "prompts" {
  for_each = local.locale_prompt_files_map
  filename = each.value
}

data "aws_connect_instance" "connect_instance" {
  instance_alias = var.connect_instance_alias
}

data "aws_caller_identity" "current" {}

data "aws_lambda_function" "qic_create_session" {
  function_name = "aicc-${var.env}-lmd-qic-create-session"
}

data "aws_lambda_function" "qic_apigateway_caller" {
  function_name = "aicc-${var.env}-lmd-qic-apigateway-caller"
}




data "aws_iam_role" "lex_role" {
  name = "aicc-${var.env}-role-lex-nova-bot-invoke"
}