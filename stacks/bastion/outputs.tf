output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_ssh_user" {
  value = "ec2-user"
}

output "bastion_key_path" {
  value = local_sensitive_file.bastion_key.filename
}
