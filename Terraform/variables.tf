variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources in."
  default     = "us-east-1"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"
}

variable "ec2_key_name" {
  type        = string
  description = "Optional EC2 key pair name for SSH access. Leave empty for none."
  default     = ""
}

variable "resource_prefix" {
  type        = string
  description = "Prefix to apply to resource names."
  default     = "pacerpro"
}