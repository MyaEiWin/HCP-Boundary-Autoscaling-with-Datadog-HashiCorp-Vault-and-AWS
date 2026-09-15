output "webhook_base_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "scale_out_webhook_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/scale-out"
}

output "scale_in_webhook_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/scale-in"
}

output "scale_action_role_arn" {
  value = aws_iam_role.scale_action.arn
}
