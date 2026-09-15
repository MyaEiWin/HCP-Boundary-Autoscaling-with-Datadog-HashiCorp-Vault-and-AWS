resource "aws_security_group" "target" {
  name_prefix = "${local.name_prefix}-target-"
  description = "Direct SSH access to the lab target from trusted administrator networks only."
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH from trusted administrator networks"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "Outbound access for Ubuntu package updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-target"
  }
}

