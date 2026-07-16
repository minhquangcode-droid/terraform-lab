output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "EC2 instance ARN"
  value       = aws_instance.this.arn
}

output "availability_zone" {
  description = "Availability Zone of the instance"
  value       = aws_instance.this.availability_zone
}

output "private_ip" {
  description = "Private IPv4 address"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IPv4 address, if assigned"
  value       = aws_instance.this.public_ip
}

output "private_dns" {
  description = "Private DNS name"
  value       = aws_instance.this.private_dns
}

output "public_dns" {
  description = "Public DNS name, if assigned"
  value       = aws_instance.this.public_dns
}