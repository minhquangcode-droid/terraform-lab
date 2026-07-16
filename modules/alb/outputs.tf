output "load_balancer_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.this.id
}

output "load_balancer_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Canonical hosted zone ID used by Route 53 alias records"
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the application Target Group"
  value       = aws_lb_target_group.this.arn
}

output "target_group_name" {
  description = "Name of the application Target Group"
  value       = aws_lb_target_group.this.name
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}