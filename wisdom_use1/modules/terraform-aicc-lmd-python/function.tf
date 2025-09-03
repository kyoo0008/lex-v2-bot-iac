# Copyright © Amazon.com and Affiliates: This deliverable is considered Developed Content as defined in the AWS Service Terms and the SOW between the parties dated [March 18, 2024].

# -------------------------------------------------------------------------------------------------
# // Lambda function
# -------------------------------------------------------------------------------------------------
resource "aws_lambda_function" "lmd_func" {
  function_name = local.func_full_name
  description   = try(var.func_description, "${local.func_hierarchy} lambda function")
  role          = aws_iam_role.lmd_exec_role.arn

  // Bundle destination
  package_type     = "Zip"
  filename         = data.archive_file.local_lambda_file_zip.output_path
  source_code_hash = data.archive_file.local_lambda_file_zip.output_sha256
  publish          = false

  // Runtime
  architectures = var.func_architecture
  runtime       = var.func_runtime
  handler       = var.func_handler
  timeout       = var.func_timeout

  // Sizing
  memory_size = var.func_memory_size_mb
  ephemeral_storage {
    size = var.func_storage_size_mb
  }

  //AWS Managed Lambda Layer for Pandas
  layers = var.func_layer

  // Environment
  environment {
    variables = var.func_environment_variables
  }

  logging_config {
    log_format = "Text"
    log_group  = local.func_hierarchy
  }

  // X-Ray
  tracing_config {
    mode = var.func_tracing_mode
  }

  // etc.
  tags = {
    # Resource Management
    Name     = local.func_full_name
    Severity = (var.env == "prd") ? "s1" : "s4"
    Service  = "${var.application}-${var.boundary}-${var.func_name}"
  }

  depends_on = [
    aws_cloudwatch_log_group.lmd_func,
    data.archive_file.local_lambda_file_zip
  ]
}

resource "aws_cloudwatch_log_group" "lmd_func" {
  name              = local.func_hierarchy
  retention_in_days = (var.env == "prd") ? 3 : 7
}

# -------------------------------------------------------------------------------------------------
# // Lambda function :: Local File to ZIP
# -------------------------------------------------------------------------------------------------

data "archive_file" "local_lambda_file_zip" {
  type        = "zip"
  source_dir  = var.func_source_path
  output_path = var.func_source_zip_path
}

