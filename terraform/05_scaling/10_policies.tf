resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-scale-out"
  autoscaling_group_name = local.worker_asg_name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment      = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project_name}-scale-in"
  autoscaling_group_name = local.worker_asg_name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment      = -1
  cooldown               = 600
}
