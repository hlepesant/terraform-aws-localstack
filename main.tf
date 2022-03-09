#---------------------------------------------------------
# Create Basic VPC and Subnet
#---------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_flow_log" "main" {
  log_destination      = aws_s3_bucket.main.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
}

resource "aws_s3_bucket" "main" {
  bucket = "awsflowlog"
}

resource "aws_subnet" "vpc_private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.vpc_private_subnet
}

#---------------------------------------------------------
# Create Security Group
#---------------------------------------------------------

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = format("%s-%s", var.prefix, lower(replace(var.sg_name, "/[[:^alnum:]]/", "")))
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-icmp"]
}

#---------------------------------------------------------
# Create DynamoDB
#---------------------------------------------------------

resource "aws_dynamodb_table" "main" {
  #tfsec:ignore:AWS086
  name             = format("%s-%s", var.prefix, lower(replace(var.db_name, "/[[:^alnum:]]/", "")))
  hash_key         = var.dynamo_hash_key
  stream_enabled   = var.dynamo_stream_enabled
  stream_view_type = var.dynamo_stream_view_type
  read_capacity    = var.dynamo_read
  write_capacity   = var.dynamo_write

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = var.dynamo_encryption
  }

  attribute {
    name = "id"
    type = "S"
  }
}

#---------------------------------------------------------
# Create IAM for EC2 and DynamoDB
#---------------------------------------------------------

resource "aws_iam_role" "ec2_dynamodb_role" {
  name = "ec2_dynamodbrole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : [
            "ec2.amazonaws.com"
          ]
        },
        "Action" : [
          "sts:AssumeRole"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_policy" {
  name        = "ec2_policy"
  description = "ec2 policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "exampledb",
        "Effect" : "Allow",
        "Action" : "dynamodb:*",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_attach" {
  role       = aws_iam_role.ec2_dynamodb_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_dynamodb_role.name
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------
# Create EC2 using module - Ideally the VPC and other
# components should use the same approach
# ---------------------------------------------------------

module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.4"

  name                   = format("%s-%s", var.prefix, lower(replace(var.ec2_name, "/[[:^alnum:]]/", "")))
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.vpc_private_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [module.security_group.security_group_id]

  tags = merge({ "ResourceName" = format("%s", var.ec2_name) }, var.tags, )
}
