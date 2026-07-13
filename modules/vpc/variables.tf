variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "tag" {
  type    = string
  default = "Create by terraform"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "t" {
  type    = string
  default = "us-east-1"
}
