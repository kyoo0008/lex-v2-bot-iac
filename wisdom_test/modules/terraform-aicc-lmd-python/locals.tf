# Copyright © Amazon.com and Affiliates: This deliverable is considered Developed Content as defined in the AWS Service Terms and the SOW between the parties dated [March 18, 2024].

locals {
  naming_prefix = "${var.application}-${var.env}"

  # execution-role
  role_full_name   = "${local.naming_prefix}-role-${var.func_name}-exec"
  policy_full_name = "${local.naming_prefix}-policy-${var.func_name}"

  # function
  func_full_name = "${local.naming_prefix}-lmd-${var.func_name}"
  func_hierarchy = "/aws/lmd/${var.application}-${var.boundary}/${var.func_name}"
  func_zip_file  = var.func_source_zip_path != null ? var.func_source_zip_path : "${path.module}/initial-function/app.zip"
}
