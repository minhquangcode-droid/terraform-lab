resource "aws_vpc" "this" {

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    description = var.tag
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "internet-gateway"
  }
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required", "opted-in"]
  }
}

locals {
  # Build a predictable list containing at most var.az_count AZs:
  # 1. data.aws_availability_zones.available.names returns all available AZ names.
  # 2. sort(...) keeps their order stable, for example a, b, then c.
  # 3. min(...) prevents slice from requesting more AZs than the Region provides.
  # 4. slice(list, 0, end) selects items from index 0 up to, but not including, end.
  # Example: if az_count = 2, the result can be ["us-east-1a", "us-east-1b"].

  availability_zones = slice(
    sort(data.aws_availability_zones.available.names),
    0,
    min(var.az_count, length(data.aws_availability_zones.available.names))
  )
}


resource "aws_subnet" "public" {
  # Convert the ordered AZ list into a map such as:
  # input: ["us-east-1a", "us-east-1b"]
  # output: { "us-east-1a" = 0, "us-east-1b" = 1 }
  # Terraform creates one subnet per entry and keeps the AZ name as
  # the stable resource key: aws_subnet.public["us-east-1a"].

  for_each = {
    for index, az in local.availability_zones : az => index
  }

  # each.key is the AZ name; each.value is its zero-based index.
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key

  # Split the VPC CIDR into smaller networks. For a /16 VPC,
  # adding 8 network bits creates /24 subnets.
  cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value)

  # Instances launched here receive a public IPv4 address by default.
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = {
    for index, az in local.availability_zones : az => index
  }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 10)
  map_public_ip_on_launch = false

  tags = {
    Name = "private-${each.key}"
  }
}


resource "aws_subnet" "private_database" {
  for_each = {
    for index, az in local.availability_zones : az => index
  }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 20)
  map_public_ip_on_launch = false

  tags = {
    Name = "private-database-${each.key}"
  }
}


# resource "aws_eip" "nat" {
#   domain = "vpc"

#   tags = {
#     Name = "nat-gateway-eip"
#   }
# }

# resource "aws_nat_gateway" "nat_gw" {
#   allocation_id = aws_eip.nat.id

#   subnet_id = aws_subnet.public[
#     local.availability_zones[0]
#   ].id

#   tags = {
#     Name = "nat-gateway-${local.availability_zones[0]}"
#   }

#   depends_on = [aws_internet_gateway.igw]
# }