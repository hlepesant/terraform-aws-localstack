#---------------------------------------------------------
# Create Basic VPC and Subnet
#---------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "vpc_private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.vpc_private_subnet
}

#---------------------------------------------------------
# Create Security Group
#---------------------------------------------------------

resource "aws_security_group" "allow_icmp" {
  name        = "allow_icmp"
  description = "Allow ICMP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "ICMP from VPC"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "allow_icmp"
  }
}

