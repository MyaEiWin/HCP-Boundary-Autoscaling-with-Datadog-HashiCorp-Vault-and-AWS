data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "boundary_worker" {
  name               = "${var.project_name}-worker"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "boundary_worker" {
  name = "${var.project_name}-worker"
  role = aws_iam_role.boundary_worker.name
}

resource "aws_iam_role_policy" "boundary_worker_lifecycle" {
  name = "boundary-worker-lifecycle"
  role = aws_iam_role.boundary_worker.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:RecordLifecycleActionHeartbeat",
        "autoscaling:DescribeAutoScalingInstances"
      ]
      Resource = "*"
    }]
  })
}
