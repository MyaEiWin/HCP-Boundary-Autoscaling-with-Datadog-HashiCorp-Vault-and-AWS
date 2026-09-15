resource "aws_apigatewayv2_api" "webhook" {
  name          = "${var.project_name}-datadog-webhook"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "scale_action" {
  api_id                 = aws_apigatewayv2_api.webhook.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.scale_action.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "scale_out" {
  api_id    = aws_apigatewayv2_api.webhook.id
  route_key = "POST /scale-out"
  target    = "integrations/${aws_apigatewayv2_integration.scale_action.id}"
}

resource "aws_apigatewayv2_route" "scale_in" {
  api_id    = aws_apigatewayv2_api.webhook.id
  route_key = "POST /scale-in"
  target    = "integrations/${aws_apigatewayv2_integration.scale_action.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.webhook.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_action.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook.execution_arn}/*/*"
}
