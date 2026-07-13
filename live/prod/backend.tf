terraform {

  backend "s3" {

    bucket = "lab-terraform-state-vmq"

    key = "prod/app.tfstate"

    region = "us-east-1"

  }

}