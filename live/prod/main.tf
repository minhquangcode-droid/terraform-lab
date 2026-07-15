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
      description                  = "Allow SSH to Bastion"
      direction                    = "ingress"
      ip_protocol                  = "tcp"
      from_port                    = 22
      to_port                      = 22
      cidr_ipv4                    = "0.0.0.0/0"
    }

    allow_all_egress = {
      direction   = "egress"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}