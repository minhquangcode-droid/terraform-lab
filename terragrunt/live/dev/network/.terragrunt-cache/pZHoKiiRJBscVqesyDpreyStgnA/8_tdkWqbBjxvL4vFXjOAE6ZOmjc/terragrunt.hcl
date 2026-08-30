include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/vpc"
}

inputs = {
  vpc_cidr = "10.10.0.0/16"
  az_count = 2
  tag      = "terragrunt-dev"
}