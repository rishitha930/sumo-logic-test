provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = var.resource_prefix
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "instance" {
  name        = "${local.name_prefix}-instance-sg"
  description = "Security group for the monitored EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-instance-sg"
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.amzn2.id
  instance_type = var.ec2_instance_type
  subnet_id     = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name      = var.ec2_key_name != "" ? var.ec2_key_name : null

  tags = {
    Name = "${local.name_prefix}-app"
  }
}

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
}

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda" {
  name        = "${local.name_prefix}-lambda-policy"
  description = "Least-privilege policy for the reboot Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:RebootInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_function"
  output_path = "${path.module}/build/lambda.zip"
}

resource "aws_lambda_function" "reboot" {
  function_name = "${local.name_prefix}-reboot"
  description   = "Reboots an EC2 instance when a Sumo Logic alert fires"
  runtime       = "python3.11"
  handler       = "lambda_function.handler"
  role          = aws_iam_role.lambda.arn
  filename      = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout       = 30

  environment {
    variables = {
      INSTANCE_ID  = aws_instance.app.id
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}
