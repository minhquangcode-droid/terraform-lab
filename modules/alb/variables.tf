variable "name" {
  description = "Name of the Application Load Balancer"
  type        = string

  validation {
    condition     = length(var.name) <= 29
    error_message = "name must contain no more than 29 characters."
  }
}

variable "vpc_id" {
  description = "VPC where the target group is created"
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs used by the ALB"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "An Application Load Balancer requires at least two subnets."
  }
}

variable "security_group_ids" {
  description = "Security group IDs attached to the ALB"
  type        = list(string)
}

variable "internal" {
  description = "Whether the ALB is internal"
  type        = bool
  default     = false
}

variable "listener_port" {
  description = "Port on which the ALB accepts requests"
  type        = number
  default     = 80
}

variable "target_port" {
  description = "Port used by the ALB to communicate with targets"
  type        = number
  default     = 80
}

variable "target_protocol" {
  description = "Protocol used to communicate with targets"
  type        = string
  default     = "HTTP"

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.target_protocol)
    error_message = "target_protocol must be HTTP or HTTPS."
  }
}

variable "target_type" {
  description = "Target type: instance, ip or lambda"
  type        = string
  default     = "instance"

  validation {
    condition     = contains(["instance", "ip", "lambda"], var.target_type)
    error_message = "target_type must be instance, ip or lambda."
  }
}

variable "health_check" {
  description = "Target Group health check configuration"

  type = object({
    enabled             = optional(bool, true)
    path                = optional(string, "/")
    port                = optional(string, "traffic-port")
    protocol            = optional(string, "HTTP")
    matcher             = optional(string, "200-399")
    interval            = optional(number, 30)
    timeout             = optional(number, 5)
    healthy_threshold   = optional(number, 2)
    unhealthy_threshold = optional(number, 3)
  })

  default = {}
}

variable "deregistration_delay" {
  description = "Seconds to wait before deregistering a target"
  type        = number
  default     = 30
}

variable "enable_deletion_protection" {
  description = "Prevent accidental ALB deletion"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}