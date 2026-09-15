data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zone = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])
  name_prefix       = var.project_name
}

resource "aws_subnet" "target" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-target-public"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name = "${local.name_prefix}-public"
  }
}

resource "aws_route_table_association" "target" {
  subnet_id      = aws_subnet.target.id
  route_table_id = aws_route_table.public.id
}

