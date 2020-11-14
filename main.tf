terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}

# Create a VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "eks_vpc_subnet_public" {
  count = 2

  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index)
  availability_zone = ["us-east-2a", "us-east-2b"][count.index]

  tags = {
    Name = "Public Subnet"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "eks_vpc_subnet_private" {
  count = 2

  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index + 10)
  availability_zone = ["us-east-2a", "us-east-2b"][count.index]

  tags = {
    Name = "Private Subnet"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"

  }
}

resource "aws_security_group" "allow_sg" {
  name        = "allow_sg"
  description = "Allow all ag traffic"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  tags = {
    Name = "allow_sg"
  }
}

resource "aws_kms_key" "eks_key" {
  description             = "KMS key for EKS"
  deletion_window_in_days = 7
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "main"
  }
}

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.eks_vpc.id
  route_table_id = aws_route_table.r.id
}

resource "aws_route_table_association" "public_route_table_assoc" {
  count = 2
  subnet_id  = aws_subnet.eks_vpc_subnet_public[count.index].id
  route_table_id = aws_route_table.r.id
}

# Endpoints

locals {
  required_endpoints = ["com.amazonaws.us-east-2.ec2",
             "com.amazonaws.us-east-2.ecr.dkr",
             "com.amazonaws.us-east-2.ecr.api",
             "com.amazonaws.us-east-2.logs",
             "com.amazonaws.us-east-2.sts",
             "com.amazonaws.us-east-2.elasticloadbalancing",
             "com.amazonaws.us-east-2.autoscaling",
             "com.amazonaws.us-east-2.appmesh-envoy-management",
  ]
}

resource "aws_vpc_endpoint" "eks_endpoint" {
  count = length(local.required_endpoints)
  vpc_id       = aws_vpc.eks_vpc.id
  service_name = local.required_endpoints[count.index]
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.allow_sg.id,
    aws_security_group.endpoint_sg.id
  ]

  subnet_ids = aws_subnet.eks_vpc_subnet_private[*].id

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "eks_s3_endpoint" {
  vpc_id       = aws_vpc.eks_vpc.id
  service_name = "com.amazonaws.us-east-2.s3"
}

resource "aws_vpc_endpoint_route_table_association" "eks_s3_endpoint_rt_association" {
  route_table_id  = aws_route_table.private_route_table.id
  vpc_endpoint_id = aws_vpc_endpoint.eks_s3_endpoint.id
}

resource "aws_security_group" "endpoint_sg" {
  name        = "endpoint_sg"
  description = "Allow traffic from vpc"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.eks_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}
resource "aws_eip" "natgw-ip" {
  vpc = true
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.natgw-ip.id
  subnet_id     = aws_subnet.eks_vpc_subnet_public[0].id

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gw.id
  }

  tags = {
    Name = "private routing"
  }
}

resource "aws_route_table_association" "private_route_table_assoc" {
  count = 2
  subnet_id  = aws_subnet.eks_vpc_subnet_private[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}
