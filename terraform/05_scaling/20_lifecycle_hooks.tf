resource "aws_autoscaling_lifecycle_hook" "launch" {
  count                  = var.enable_launch_hook ? 1 : 0
  name                   = "boundary-worker-launch"
  autoscaling_group_name = local.worker_asg_name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  heartbeat_timeout      = 600
  default_result         = "ABANDON"
}

resource "aws_autoscaling_lifecycle_hook" "termination" {
  name                   = "boundary-worker-termination"
  autoscaling_group_name = local.worker_asg_name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 600
  default_result         = "CONTINUE"
}
