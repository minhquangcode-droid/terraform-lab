variable "name" {
  description = "Security group name"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "description" {
  description = "Security group description"
  type        = string
  default     = "Managed by Terraform"
}

variable "rules" {
  description = "Ingress and egress security group rules"

  type = map(object({
    description                  = optional(string)
    direction                    = string
    ip_protocol                  = string
    from_port                    = optional(number)
    to_port                      = optional(number)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
  }))

  default = {}

  validation {
    condition = alltrue([
      for rule in values(var.rules) :
      contains(["ingress", "egress"], rule.direction)
    ])

    error_message = "Rule direction must be either ingress or egress."
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) :
      (
        (rule.cidr_ipv4 != null ? 1 : 0) +
        (rule.cidr_ipv6 != null ? 1 : 0) +
        (rule.prefix_list_id != null ? 1 : 0) +
        (rule.referenced_security_group_id != null ? 1 : 0)
      ) == 1
    ])

    error_message = "Each rule must define exactly one source or destination."
  }
}

variable "tags" {
  description = "Tags to apply to the security group"
  type        = map(string)
  default     = {}
}
