terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  required_version = ">= 0.14"
}

provider "aws" {
  region = "us-east-2"
}

# Create a VPC
resource "aws_vpc" "hero_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.hero_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-2"
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.hero_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-2"
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.hero_vpc.id
}

# Create an NAT Gateway (requires an Elastic IP)
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public_subnet.id
  allocation_id = aws_eip.nat.id
}

# For the public subnet to allow traffic to/from the Internet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.hero_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# For the private subnet to route through the NAT Gateway
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.hero_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# Public Instance (Web Server)
resource "aws_instance" "web_server" {
  ami           = "ami-05848400cdd2a1558"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = "leftattention-hero"

  security_groups = [aws_security_group.web_sg.id]
}

# Private Instance (Database Server)
resource "aws_instance" "db_server" {
  ami           = "ami-05848400cdd2a1558"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id
  key_name      = "leftattention-hero"

  security_groups = [aws_security_group.db_sg.id]
}

# For the web server (allow HTTP/HTTPS and SSH from the IP)
resource "aws_security_group" "web_sg" {
  name        = "web_server_sg"
  description = "Allow HTTP, HTTPS, and SSH"
  vpc_id      = aws_vpc.hero_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["18.189.132.140/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# For the database server (only allow internal traffic)
resource "aws_security_group" "db_sg" {
  name        = "db_server_sg"
  description = "Allow internal traffic only"
  vpc_id      = aws_vpc.hero_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Output the public IP of the web server
output "web_server_ip" {
  value = aws_instance.web_server.public_ip
}
