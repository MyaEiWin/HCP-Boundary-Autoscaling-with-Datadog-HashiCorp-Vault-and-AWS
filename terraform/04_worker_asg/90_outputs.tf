output "asg_name" { value = aws_autoscaling_group.worker.name }
output "worker_security_group_id" { value = aws_security_group.worker.id }

