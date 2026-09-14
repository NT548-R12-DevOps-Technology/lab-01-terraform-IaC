output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet."
  value       = aws_subnet.private.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "ID of the public NAT Gateway."
  value       = aws_nat_gateway.this.id
}

output "nat_gateway_public_ip" {
  description = "Elastic IPv4 address attached to the NAT Gateway."
  value       = aws_eip.nat.public_ip
}

output "public_route_table_id" {
  description = "ID of the public subnet route table."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private subnet route table."
  value       = aws_route_table.private.id
}
