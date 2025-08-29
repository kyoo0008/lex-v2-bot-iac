locals {
  output_file_path = "${path.module}/.kb_output_${var.locale}.json"
  kb_result = fileexists(local.output_file_path) ? jsondecode(data.local_file.kb_output.content) : {}

}

