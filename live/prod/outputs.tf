output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "private_database_subnet_ids" {
  value = module.vpc.private_database_subnet_ids
}

output "internet_gateway_id" {
  value = module.vpc.internet_gateway_id
}

output "availability_zones" {
  value = module.vpc.availability_zones
}

output "bastion_instance_id" {
  value = module.bastion_ec2.instance_id
}

output "bastion_public_ip" {
  description = "Public IPv4 address, if assigned"
  value       = module.bastion_ec2.public_ip
}

output "alb_dns_name" {
  value = module.alb.dns_name
}