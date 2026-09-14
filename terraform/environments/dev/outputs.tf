output "vpc_id" {
  description = "ID of the lab VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the subnet containing the bastion and NAT Gateway."
  value       = module.networking.public_subnet_id
}

output "private_subnet_id" {
  description = "ID of the subnet containing the private EC2 instance."
  value       = module.networking.private_subnet_id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway attached to the VPC."
  value       = module.networking.internet_gateway_id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway used for private subnet Internet egress."
  value       = module.networking.nat_gateway_id
}

output "nat_gateway_public_ip" {
  description = "Elastic IPv4 address expected when the private EC2 accesses the Internet."
  value       = module.networking.nat_gateway_public_ip
}

output "public_route_table_id" {
  description = "ID of the route table with an Internet Gateway default route."
  value       = module.networking.public_route_table_id
}

output "private_route_table_id" {
  description = "ID of the route table with a NAT Gateway default route."
  value       = module.networking.private_route_table_id
}

output "public_sg_id" {
  description = "ID of the bastion Security Group."
  value       = module.security.public_sg_id
}

output "private_sg_id" {
  description = "ID of the private EC2 Security Group."
  value       = module.security.private_sg_id
}

output "public_instance_id" {
  description = "IDs of public EC2 instances, ordered by count index."
  value       = module.ec2.public_instance_id
}

output "public_instance_public_ip" {
  description = "Public IPv4 addresses of bastions, ordered by count index."
  value       = module.ec2.public_instance_public_ip
}

output "public_instance_private_ip" {
  description = "Private IPv4 addresses of bastions, ordered by count index."
  value       = module.ec2.public_instance_private_ip
}

output "private_instance_id" {
  description = "IDs of private EC2 instances, ordered by count index."
  value       = module.ec2.private_instance_id
}

output "private_instance_private_ip" {
  description = "Private EC2 IPv4 addresses, ordered by count index."
  value       = module.ec2.private_instance_private_ip
}
