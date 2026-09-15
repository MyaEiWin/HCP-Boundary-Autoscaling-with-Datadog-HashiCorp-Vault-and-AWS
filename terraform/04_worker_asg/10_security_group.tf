resource "aws_security_group" "worker" {
  name_prefix = "${var.project_name}-worker-"
  vpc_id      = local.target_vpc_id

  ingress {
    description = "Boundary proxy traffic from approved clients"
    from_port   = 9202
    to_port     = 9202
    protocol    = "tcp"
    cidr_blocks = var.allowed_client_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "target_from_worker" {
  type                     = "ingress"
  description              = "SSH from Boundary workers"
  security_group_id        = local.target_security_group_id
  source_security_group_id = aws_security_group.worker.id
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
}
