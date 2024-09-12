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
  # filename = "terraform-key.pem"
}

resource "local_file" "private_key" {
  content  = tls_private_key.rsa_4096.private_key_pem
  filename = "terraform-key.pem"
  provisioner "local-exec" {
    command = "chmod 400 ${self.filename}"
  }
}


resource "aws_instance" "ec2_server" {
  ami           = "ami-05134c8ef96964280"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.key_pair.key_name

  subnet_id                   = aws_subnet.Public_subnet.id
  vpc_security_group_ids      = [aws_security_group.ic_sg.id]
  associate_public_ip_address = true

  tags = {
    "Name" : "ec2_server"
  }

  # provisioner "local-exec" {
  #   command = "echo ${aws_instance.ec2_server.public_ip} >> /etc/ansible/hosts"
  # }
  # provisioner "local-exec" {
  #   command = <<EOT
  #     echo "[ec2]" > ../ansible/inventory.ini
  #     echo "$(terraform output -raw ec2_public_ip)" >> ../ansible/inventory.ini
  #     ansible-playbook -i ../ansible/inventory.ini --user ubuntu --private-key terraform-key.pem ../ansible/docker_playbook.yml

  #   EOT
  # }
  # provisioner "local-exec" {
  # command = <<EOT
  #   echo "[ec2]" > ../ansible/inventory.ini
  #   echo "$(terraform output -raw ec2_public_ip) ansible_user=ubuntu" >> ../ansible/inventory.ini
  #   ansible-playbook -i ../ansible/inventory.ini --private-key ./ic_key ../ansible/docker_playbook.yml
  # EOT
      # ansible-playbook -i ../ansible/inventory.ini --user ubuntu --private-key ic_key ../ansible/docker_playbook.yml

  # }

}

output "ec2_public_ip" {
  value = aws_instance.ec2_server.public_ip
}

 
resource "local_file" "inventory" {
  depends_on = [aws_instance.ec2_server]

  filename = "${path.module}/inventory.ini"

  content = templatefile("${path.module}/inventory.tmpl", {
    instance_ip = aws_instance.ec2_server.public_ip,
    key_path = "${path.module}/terraform-key.pem"
  })

  provisioner "local-exec" {
    command = "chmod 400 ${self.filename}"
  }
}

resource "null_resource" "run_ansible" {
  depends_on = [local_file.inventory]

  provisioner "local-exec" {
    command = "ansible-playbook -i ../ansible/inventory.ini ../ansible/docker-playbook.yml"
    working_dir = path.module
  }
}