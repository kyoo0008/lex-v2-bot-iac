data "aws_connect_instance" "connect_instance" {
  instance_alias = var.connect_instance_alias
}
