data "archive_file" "scale_action" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/scale-action.zip"
}

resource "aws_lambda_function" "scale_action" {
  function_name    = "${var.project_name}-datadog-scale-action"
  role             = aws_iam_role.scale_action.arn
  handler          = "scale_action_handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.scale_action.output_path
  source_code_hash = data.archive_file.scale_action.output_base64sha256

  environment {
    variables = {
      ASG_NAME              = var.asg_name
      SCALE_OUT_POLICY_NAME = element(reverse(split("/", var.scale_out_policy_arn)), 0)
      SCALE_IN_POLICY_NAME  = element(reverse(split("/", var.scale_in_policy_arn)), 0)
      VAULT_ADDR            = var.vault_addr
      VAULT_NAMESPACE       = var.vault_namespace
      VAULT_AWS_ROLE        = "boundary-datadog-scale-action"
    }
  }
}
