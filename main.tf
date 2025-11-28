terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
  required_version = ">= 1.2"
}

provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_vpc" "new_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "VPC-Para-App-ArreglaYa"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.new_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet - ArreglaYa"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.new_vpc.id

  tags = {
    Name = "ArreglaYa-IGW"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.new_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app_sg" {
  name        = "app_reverse_proxy_sg"
  description = "Security group for Nginx Reverse Proxy and Docker app"
  vpc_id      = aws_vpc.new_vpc.id

  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ReverseProxy-SG"
  }
}

resource "aws_s3_bucket" "app_storage" {
  bucket = "arregla-ya-users-storage-prod-2025" 
  tags = {
    Name = "ArreglaYaProdAppStorage"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_ownership_controls" "app_ownership" {
  bucket = aws_s3_bucket.app_storage.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "app_storage_block" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "public_read_policy" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.app_storage.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket = aws_s3_bucket.app_storage.id
  policy = data.aws_iam_policy_document.public_read_policy.json

  depends_on = [
    aws_s3_bucket_ownership_controls.app_ownership,
    aws_s3_bucket_public_access_block.app_storage_block
  ]
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  subnet_id     = aws_subnet.public.id
  tags = {
    Name : "arregla-ya server"
  }
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  user_data = templatefile("${path.module}/scripts/install_and_deploy.sh", {

    APP_DIR                = "/var/www/app"
    BACKEND_HOST_PORT      = var.backend_host_port
    FRONTEND_SOURCE_FOLDER = "arreglaya"
    FRONTEND_BUILD_FOLDER  = "build"
    S3_BUCKET_NAME         = aws_s3_bucket.app_storage.bucket


    PG_PASS        = var.postgres_password_prod
    LDAP_PASS      = var.ldap_admin_password_prod
    AWS_ACCESS_KEY = var.aws_access_key
    AWS_SECRET_KEY = var.aws_secret_key


  })
}