output "public_sg_id" {
  description = "ID of the bastion Security Group."
  value       = aws_security_group.public.id
}

output "private_sg_id" {
  description = "ID of the private EC2 Security Group."
  value       = aws_security_group.private.id
}
