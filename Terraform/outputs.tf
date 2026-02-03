output "ec2_instance_id" {
  value       = aws_instance.app.id
  description = "ID of the EC2 instance to be rebooted."
}

output "lambda_function_name" {
  value       = aws_lambda_function.reboot.function_name
  description = "Lambda function name."
}

output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "SNS topic ARN for notifications."
}