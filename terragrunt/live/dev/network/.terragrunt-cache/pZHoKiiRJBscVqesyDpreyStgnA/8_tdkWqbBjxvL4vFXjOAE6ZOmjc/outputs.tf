output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public : subnet.id]
}


output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private : subnet.id]
}

output "private_database_subnet_ids" {
  value = [for subnet in aws_subnet.private_database : subnet.id]
}

output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id
}

output "availability_zones" {
  value = local.availability_zones
}

output "subnet_ids" {
  value = concat(
    [for az in local.availability_zones : aws_subnet.public[az].id],
    [for az in local.availability_zones : aws_subnet.private[az].id],
    [for az in local.availability_zones : aws_subnet.private_database[az].id]
  )
}