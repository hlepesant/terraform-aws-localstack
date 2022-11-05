# ---------------------------------------------------------
# Create EC2 using module - Ideally the VPC and other
# components should use the same approach
# ---------------------------------------------------------
resource "aws_instance" "main" {
  ami           = "ami-005e54dee72cc1d00"
  instance_type = "t3.medium"

  subnet_id   = aws_subnet.vpc_private_subnet.id
}
