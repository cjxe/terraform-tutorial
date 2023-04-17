# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# The name "first-vpc" is the name in this terraform file
resource "aws_vpc" "first-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}

resource "aws_subnet" "first-subnet" {
  vpc_id     = aws_vpc.first-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "prod-subnet2"
  }
}
