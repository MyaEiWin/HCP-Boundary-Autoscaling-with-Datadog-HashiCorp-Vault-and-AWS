output "automation_role_arns" { value = { for name, role in aws_iam_role.automation : name => role.arn } }
output "automation_function_names" { value = { for name, function in aws_lambda_function.automation : name => function.function_name } }
