data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "admin" {
  key_name_prefix = "${local.name_prefix}-admin-"
  public_key      = var.admin_public_key

  tags = {
    Name = "${local.name_prefix}-admin"
  }
}

resource "aws_instance" "target" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.target_instance_type
  subnet_id                   = aws_subnet.target.id
  vpc_security_group_ids      = [aws_security_group.target.id]
  key_name                    = aws_key_pair.admin.key_name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    apt-get update
    apt-get install -y openssh-server
    systemctl enable --now ssh
  EOF

  tags = {
    Name = "${local.name_prefix}-ssh-target"
    Role = "boundary-ssh-target"
  }
}

