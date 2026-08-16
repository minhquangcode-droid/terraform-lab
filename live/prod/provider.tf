terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.54"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  
  assume_role {
    role_arn = "arn:aws:iam::931228356332:role/sanbox-terraform-role"
  }
}