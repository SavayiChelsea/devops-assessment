output "app_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "db_endpoint" {
  description = "RDS connection endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}
