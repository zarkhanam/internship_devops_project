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
  region = "us-east-1"
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
        gatewa_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "PublicRTAssociation"{
    subnet_id = aws_subnet.Public_subnet.id
    route_table_id = aws_route_table.PublicRT.id
}

