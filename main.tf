# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Define a VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-tutorial"
  }

}

# Define an Internet Gateway
resource "aws_internet_gateway" "prod_igw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "terraform-tutorial"
  }
}

# Create custom route table
resource "aws_route_table" "custom_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod_igw.id
  }

  tags = {
    Name = "terraform-tutorial"
  }
}

# Define a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  # Associate the public subnet with the internet gateway
  tags = {
    Name = "public_subnet"
  }

  depends_on = [
    aws_internet_gateway.prod_igw
  ]
}

# Define a security group for the public subnet
resource "aws_security_group" "public_sg" {
  name_prefix = "public_sg"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description = "SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # any ip address can access it
  }

  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # any ip address can access it
  }

  ingress {
    description = "HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # any ip address can access it
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# Associate a subnet with a route table
resource "aws_route_table_association" "custom_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.custom_route_table.id
}

# Define two EC2 instances
resource "aws_instance" "ec2_instance_1" {
  ami           = "ami-007855ac798b5175e"
  instance_type = "t2.micro"
  key_name      = "main-key"

  network_interface {
    network_interface_id = aws_network_interface.eni_1.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "Hello, World" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "ec2_instance_1"
  }
}

# Define an Elastic IP for each instance
# Why do we use EIPs? https://stackoverflow.com/a/50306357/12959962
resource "aws_eip" "eip_1" {
  vpc = true
  # ! you can only specify either `instance` or `network_interface`
  instance                  = aws_instance.ec2_instance_1.id
  associate_with_private_ip = "10.0.1.50"
}

# Define an Elastic Network Interface for each instance
resource "aws_network_interface" "eni_1" {
  subnet_id = aws_subnet.public_subnet.id

  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.public_sg.id]
}

output "ec2_instance_1_private_ip" {
  value = aws_instance.ec2_instance_1.private_ip
}

output "ec2_instance_1_public_ip" {
  value = aws_eip.eip_1.public_ip
}
