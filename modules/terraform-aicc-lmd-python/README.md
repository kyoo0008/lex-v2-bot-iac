<!-- https://ileriayo.github.io/markdown-badges/#markdown-badges -->
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=Flat&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=flat&logo=amazon-aws&logoColor=white)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](./LICENSE.txt)

# terraform-aicc-connect-data-pipeline-lmd

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.lmd_func](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.lmd_exec_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lmd_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lmd_attachments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.lmd_func](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [archive_file.local_lambda_file_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_iam_policy.service_common_boundary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy_document.lmd_inline_doc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_application"></a> [application](#input\_application) | First prefix of all resource names | `string` | `"aicc"` | no |
| <a name="input_boundary"></a> [boundary](#input\_boundary) | Boundary of all resource names | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | Environment name - dev/stg/prd | `string` | n/a | yes |
| <a name="input_func_architecture"></a> [func\_architecture](#input\_func\_architecture) | Lambda function architecture | `list(string)` | <pre>[<br>  "x86_64"<br>]</pre> | no |
| <a name="input_func_description"></a> [func\_description](#input\_func\_description) | Lambda function description | `string` | `null` | no |
| <a name="input_func_environment_variables"></a> [func\_environment\_variables](#input\_func\_environment\_variables) | Lambda function environment variables | `map(string)` | <pre>{<br>  "POWERTOOLS_LOG_LEVEL": "INFO"<br>}</pre> | no |
| <a name="input_func_handler"></a> [func\_handler](#input\_func\_handler) | Lambda function handler | `string` | `"app.handler"` | no |
| <a name="input_func_inline_policy_json"></a> [func\_inline\_policy\_json](#input\_func\_inline\_policy\_json) | Lambda function inline policy | <pre>object({<br>    Version = string<br>    Statement = list(object({<br>      Sid      = string<br>      Effect   = string<br>      Action   = list(string)<br>      Resource = list(string)<br><br>      # Condition block<br>      Condition = optional(map(map(list(string))))<br>    }))<br>  })</pre> | `null` | no |
| <a name="input_func_layer"></a> [func\_layer](#input\_func\_layer) | Lambda Layer for pandas | `list(any)` | `[]` | no |
| <a name="input_func_memory_size_mb"></a> [func\_memory\_size\_mb](#input\_func\_memory\_size\_mb) | Lambda function memory size (MB) | `number` | `512` | no |
| <a name="input_func_name"></a> [func\_name](#input\_func\_name) | Lambda function name | `string` | n/a | yes |
| <a name="input_func_runtime"></a> [func\_runtime](#input\_func\_runtime) | Lambda function runtime | `string` | `"nodejs20.x"` | no |
| <a name="input_func_source_hash"></a> [func\_source\_hash](#input\_func\_source\_hash) | Lambda function source hash - if it's served, it must be set to a base64-encoded SHA256 hash of the package(Zip) file | `string` | `null` | no |
| <a name="input_func_source_path"></a> [func\_source\_path](#input\_func\_source\_path) | Lambda function source file(.zip) path - if it's served, terraform control to upload package file(.zip) | `string` | `null` | no |
| <a name="input_func_source_zip_path"></a> [func\_source\_zip\_path](#input\_func\_source\_zip\_path) | Lambda function source file(.zip) path - if it's served, terraform control to upload package file(.zip) | `string` | `null` | no |
| <a name="input_func_storage_size_mb"></a> [func\_storage\_size\_mb](#input\_func\_storage\_size\_mb) | Lambda function storage size (MB) | `number` | `512` | no |
| <a name="input_func_timeout"></a> [func\_timeout](#input\_func\_timeout) | Lambda function timeout | `number` | `5` | no |
| <a name="input_func_tracing_mode"></a> [func\_tracing\_mode](#input\_func\_tracing\_mode) | Lambda function X-Ray tracing option | `string` | `"PassThrough"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lmd_func_arn"></a> [lmd\_func\_arn](#output\_lmd\_func\_arn) | Lambda function ARN |
| <a name="output_lmd_func_invoke_arn"></a> [lmd\_func\_invoke\_arn](#output\_lmd\_func\_invoke\_arn) | Lambda function invoke ARN |
| <a name="output_lmd_func_name"></a> [lmd\_func\_name](#output\_lmd\_func\_name) | Lambda function name |
<!-- END_TF_DOCS -->
