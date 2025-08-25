# Copyright © Amazon.com and Affiliates: This deliverable is considered Developed Content as defined in the AWS Service Terms and the SOW between the parties dated [March 18, 2024].

# -------------------------------------------------------------------------------------------------
# // Lambda execution role
# -------------------------------------------------------------------------------------------------
locals {
  lmd_policy_arns = [
    "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]
}

resource "aws_iam_role" "lmd_exec_role" {
  name        = local.role_full_name
  description = try(var.func_description, local.func_hierarchy)

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  permissions_boundary = data.aws_iam_policy.service_common_boundary.arn

  # etc.
  tags = {
  }
}

resource "aws_iam_role_policy_attachment" "lmd_attachments" {
  for_each = toset(local.lmd_policy_arns)
  role     = aws_iam_role.lmd_exec_role.name

  policy_arn = each.value
}

data "aws_iam_policy" "service_common_boundary" {
  name = "com-policy-boundary-service-common"
}

data "aws_iam_policy_document" "lmd_inline_doc" {
  count = var.func_inline_policy_json != null ? 1 : 0
  dynamic "statement" {
    for_each = var.func_inline_policy_json.Statement

    content {
      sid       = statement.value.Sid
      effect    = statement.value.Effect
      actions   = tolist(statement.value.Action)
      resources = tolist(statement.value.Resource)

      dynamic "condition" {
        for_each = statement.value.Condition != null ? statement.value.Condition : {}
        content {
          test     = condition.key
          variable = keys(condition.value)[0]
          values   = tolist(values(condition.value)[0])
        }
      }
    }
  }
}

resource "aws_iam_role_policy" "lmd_inline" {
  count = var.func_inline_policy_json != null ? 1 : 0

  name   = "${local.policy_full_name}-inline"
  role   = aws_iam_role.lmd_exec_role.id
  policy = data.aws_iam_policy_document.lmd_inline_doc[0].json
}
