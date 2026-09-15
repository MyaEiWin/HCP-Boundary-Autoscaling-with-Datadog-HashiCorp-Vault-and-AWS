data "archive_file" "automation" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/automation.zip"
}

locals {
  common_environment = {
    VAULT_ADDR        = var.vault_addr
    VAULT_NAMESPACE   = var.vault_namespace
    BOUNDARY_ADDR     = var.boundary_addr
    BOUNDARY_SCOPE_ID = var.boundary_scope_id
  }
}

resource "aws_lambda_function" "automation" {
  for_each         = aws_iam_role.automation
  function_name    = "${var.project_name}-${each.key}"
  role             = each.value.arn
  handler          = "handler.${replace(each.key, "-", "_")}"
  runtime          = "python3.12"
  timeout          = 60
  filename         = data.archive_file.automation.output_path
  source_code_hash = data.archive_file.automation.output_base64sha256
  environment { variables = merge(local.common_environment, {
    VAULT_AWS_ROLE = "boundary-${each.key}"
    ASG_NAME       = var.asg_name
    DD_SITE        = var.datadog_site
  }) }
}
