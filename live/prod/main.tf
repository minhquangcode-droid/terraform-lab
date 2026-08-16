module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr = "10.0.0.0/16"
  tag      = "Create by terraform"
  az_count = 3
}


module "bastion_sg" {
  source = "../../modules/security"

  name   = "bastion-sg"
  vpc_id = module.vpc.vpc_id

  rules = {
    ssh_from_bastion = {
      description = "Allow SSH to Bastion"
      direction   = "ingress"
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = "0.0.0.0/0"
    }

    allow_all_egress = {
      direction   = "egress"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}


module "bastion_ec2" {
  source = "../../modules/ec2"

  name                        = "bastion-host"
  ami_id                      = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnet_ids[0]
  security_group_ids          = [module.bastion_sg.security_group_id]
  associate_public_ip_address = true
}

module "alb_sg" {
  source = "../../modules/security"

  name   = "alb-sg"
  vpc_id = module.vpc.vpc_id

  rules = {
    http_from_internet = {
      direction   = "ingress"
      ip_protocol = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = "0.0.0.0/0"
    }

    allow_all_egress = {
      direction   = "egress"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

module "application_sg" {
  source = "../../modules/security"

  name   = "application-sg"
  vpc_id = module.vpc.vpc_id

  rules = {
    http_from_alb = {
      direction                    = "ingress"
      ip_protocol                  = "tcp"
      from_port                    = 80
      to_port                      = 80
      referenced_security_group_id = module.alb_sg.security_group_id
    }

    ssh_from_bastion = {
      direction                    = "ingress"
      ip_protocol                  = "tcp"
      from_port                    = 22
      to_port                      = 22
      referenced_security_group_id = module.bastion_sg.security_group_id
    }

    allow_all_egress = {
      direction   = "egress"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

module "alb" {
  source = "../../modules/alb"

  name   = "application-alb"
  vpc_id = module.vpc.vpc_id

  subnet_ids = module.vpc.public_subnet_ids

  security_group_ids = [
    module.alb_sg.security_group_id
  ]

  listener_port   = 80
  target_port     = 80
  target_protocol = "HTTP"
}


module "application_asg" {
  source = "../../modules/asg"

  name          = "application"
  ami_id        = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_ids    = module.vpc.private_subnet_ids

  security_group_ids = [
    module.application_sg.security_group_id
  ]

  target_group_arns = [
    module.alb.target_group_arn
  ]

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  # Compress index.html before embedding it because EC2 user data is limited
  # to 16 KiB. A content change still creates a new Launch Template version.
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y nginx

    echo '${base64gzip(file("${path.module}/index.html"))}' \
      | base64 --decode \
      | gzip --decompress \
      > /var/www/html/index.html

    chown root:root /var/www/html/index.html
    chmod 0644 /var/www/html/index.html

    nginx -t
    systemctl enable nginx
    systemctl restart nginx
  EOF

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
