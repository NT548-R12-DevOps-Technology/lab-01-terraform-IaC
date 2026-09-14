output "public_instance_id" {
  description = "IDs of public EC2 instances, ordered by count index."
  value       = aws_instance.public[*].id
}

output "public_instance_public_ip" {
  description = "Public IPv4 addresses of bastions, ordered by count index."
  value       = aws_instance.public[*].public_ip
}

output "public_instance_private_ip" {
  description = "Private IPv4 addresses of bastions, ordered by count index."
  value       = aws_instance.public[*].private_ip
}

output "private_instance_id" {
  description = "IDs of private EC2 instances, ordered by count index."
  value       = aws_instance.private[*].id
}

output "private_instance_private_ip" {
  description = "Private EC2 IPv4 addresses, ordered by count index."
  value       = aws_instance.private[*].private_ip
}
