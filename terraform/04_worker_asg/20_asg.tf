resource "aws_launch_template" "worker" {
  name_prefix   = "${var.project_name}-worker-"
  image_id      = local.worker_ami_id
  instance_type = var.instance_type

  iam_instance_profile { name = var.worker_instance_profile_name }
  vpc_security_group_ids = [aws_security_group.worker.id]

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/scripts/worker-bootstrap.sh.tftpl", {
    region              = var.aws_region
    vault_addr          = var.vault_addr
    vault_namespace     = var.vault_namespace
    vault_aws_role      = var.vault_aws_role
    boundary_cluster_id = var.boundary_cluster_id
  }))
}

resource "aws_autoscaling_group" "worker" {
  name                = "${var.project_name}-workers"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.min_size
  vpc_zone_identifier = [local.worker_subnet_id]
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-boundary-worker"
    propagate_at_launch = true
  }
}
