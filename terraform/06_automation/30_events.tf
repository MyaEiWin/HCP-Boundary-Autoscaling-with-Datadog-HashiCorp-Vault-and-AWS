resource "aws_cloudwatch_event_rule" "session_counter" {
  name                = "${var.project_name}-session-counter"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_rule" "launch" {
  name          = "${var.project_name}-worker-launch"
  event_pattern = jsonencode({ source = ["aws.autoscaling"], "detail-type" = ["EC2 Instance-launch Lifecycle Action"], detail = { AutoScalingGroupName = [var.asg_name] } })
}

resource "aws_cloudwatch_event_rule" "termination" {
  name          = "${var.project_name}-worker-termination"
  event_pattern = jsonencode({ source = ["aws.autoscaling"], "detail-type" = ["EC2 Instance-terminate Lifecycle Action"], detail = { AutoScalingGroupName = [var.asg_name] } })
}

locals { rules = { "session-counter" = aws_cloudwatch_event_rule.session_counter, "token-broker" = aws_cloudwatch_event_rule.launch, cleanup = aws_cloudwatch_event_rule.termination } }
resource "aws_cloudwatch_event_target" "automation" {
  for_each  = local.rules
  rule      = each.value.name
  target_id = each.key
  arn       = aws_lambda_function.automation[each.key].arn
}

resource "aws_lambda_permission" "events" {
  for_each      = local.rules
  statement_id  = "AllowEventBridge${replace(title(each.key), "-", "")}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.automation[each.key].function_name
  principal     = "events.amazonaws.com"
  source_arn    = each.value.arn
}
