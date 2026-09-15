data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scale_action" {
  name               = "${var.project_name}-datadog-scale-action"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.scale_action.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "execute_scaling" {
  name = "${var.project_name}-execute-scaling-policy"
  role = aws_iam_role.scale_action.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["autoscaling:ExecutePolicy"]
      Resource = [var.scale_out_policy_arn, var.scale_in_policy_arn]
    }]
  })
}
