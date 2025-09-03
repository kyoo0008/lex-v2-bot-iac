# Copyright © Amazon.com and Affiliates: This deliverable is considered Developed Content as defined in the AWS Service Terms and the SOW between the parties dated [March 18, 2024].

output "lmd_func_arn" {
  value       = aws_lambda_function.lmd_func.arn
  description = "Lambda function ARN"
}

output "lmd_func_invoke_arn" {
  value       = aws_lambda_function.lmd_func.invoke_arn
  description = "Lambda function invoke ARN"
}

output "lmd_func_name" {
  value       = aws_lambda_function.lmd_func.function_name
  description = "Lambda function name"
}
