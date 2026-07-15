# --- Public subnet routing ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "public-route-table"
  }
}

# Send public Internet traffic to the Internet Gateway.
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Attach every public subnet to the shared public route table.
resource "aws_route_table_association" "public" {
  # aws_subnet.public is a map of subnet objects keyed by AZ name.
  # This creates one association per public subnet while preserving
  # the same stable keys, for example association.public["us-east-1a"].
  for_each = aws_subnet.public

  # each.value is the current aws_subnet.public resource object.
  # Its ID is associated with the single shared public route table.
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# --- Private application subnet routing ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "private-route-table"
  }
}

# Attach every private application subnet to the shared private route table.
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Send private application Internet traffic through the NAT Gateway.
# resource "aws_route" "private_internet" {
#   route_table_id         = aws_route_table.private.id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.nat_gw.id
# }

# --- Isolated database subnet routing ---
resource "aws_route_table" "private_database" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "private-database-route-table"
  }
}

# Attach every database subnet to the isolated database route table.
resource "aws_route_table_association" "private_database" {
  for_each = aws_subnet.private_database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_database.id
}
