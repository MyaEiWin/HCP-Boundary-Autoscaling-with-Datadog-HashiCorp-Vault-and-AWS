output "worker_role_arn" { value = aws_iam_role.boundary_worker.arn }
output "worker_instance_profile_name" { value = aws_iam_instance_profile.boundary_worker.name }
output "token_broker_role_arn" { value = aws_iam_role.token_broker.arn }

