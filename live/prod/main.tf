module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr = "10.0.0.0/16"
  tag      = "Create by terraform"
  region   = "us-east-1"
}