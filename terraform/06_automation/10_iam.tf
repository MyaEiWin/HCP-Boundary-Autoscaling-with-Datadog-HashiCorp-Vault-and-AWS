data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "automation" {
  for_each           = toset(["session-counter", "token-broker", "cleanup"])
  name               = "${var.project_name}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  for_each   = aws_iam_role.automation
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lifecycle" {
  for_each = { for name in ["token-broker", "cleanup"] : name => aws_iam_role.automation[name] }
  name     = "${var.project_name}-${each.key}-lifecycle"
  role     = each.value.id
  policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["autoscaling:CompleteLifecycleAction", "autoscaling:RecordLifecycleActionHeartbeat"], Resource = "*" }] })
}
