resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip_address

  user_data = var.user_data

  # Require IMDSv2.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = var.root_volume.volume_type
    volume_size           = var.root_volume.volume_size
    encrypted             = var.root_volume.encrypted
    delete_on_termination = var.root_volume.delete_on_termination
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}
