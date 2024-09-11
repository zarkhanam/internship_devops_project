terraform {
  required_version = ">= 0.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}


# VPC Creation

resource "aws_vpc" "AWS_VPC" {
 cidr_block = "15.0.0.0/16"
 
 tags = { 
   Name = "AWS_VPC"
 }
}

resource "aws_subnet" "Public_subnet"{
    vpc_id = aws_vpc.AWS_VPC.id
    cidr_block = "15.0.1.0/24"

}
 
resource "aws_subnet" "Private_subnet"{
    vpc_id = aws_vpc.AWS_VPC.id
    cidr_block = "15.0.2.0/24"

}

resource "aws_internet_gateway" "igw" {
 vpc_id = aws_vpc.AWS_VPC.id
 
 tags = {
   Name = "AWS_VPC_IG"
 }
}

resource "aws_route_table" "PublicRT"{
    vpc_id = aws_vpc.AWS_VPC.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "PublicRTAssociation"{
    subnet_id = aws_subnet.Public_subnet.id
    route_table_id = aws_route_table.PublicRT.id
}



resource "aws_security_group" "ic_sg" {
  name   = "IC Custom SG"
  vpc_id = aws_vpc.AWS_VPC.id

# Inbound Traffic 

    # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins traffic
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SonarQube traffic
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

# Outbound Traffic

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}       
    

resource "tls_private_key" "rsa-4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

variable "key_name" {
    type        = string
    default     = "ic_key"
}


resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa-4096.public_key_openssh
}

resource "local_file" "private_key" {
  content = tls_private_key.rsa-4096.private_key_pem
  filename = var.key_name
}

resource "aws_instance" "ic_ec2_api_server" {
  ami           = "ami-0e86e20dae9224db8"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.key_pair.key_name

  subnet_id                   = aws_subnet.Public_subnet.id
  vpc_security_group_ids      = [aws_security_group.ic_sg.id]
  associate_public_ip_address = true

  tags = {
    "Name" : "ic_ec2_instance"
  }
} 
