variable "name" {
  description = "Name prefix used by the Launch Template and ASG"
  type        = string
}

variable "ami_id" {
  description = "AMI ID used by the Launch Template"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "Private subnet IDs used by the Auto Scaling Group"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "At least one subnet ID must be provided."
  }
}

variable "security_group_ids" {
  description = "Security Group IDs attached to application instances"
  type        = list(string)
}

variable "target_group_arns" {
  description = "Target Group ARNs attached to the ASG"
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "Optional EC2 key pair name"
  type        = string
  default     = null
  nullable    = true
}

variable "iam_instance_profile_name" {
  description = "Optional IAM instance profile name"
  type        = string
  default     = null
  nullable    = true
}

variable "user_data" {
  description = "Optional unencoded EC2 startup script"
  type        = string
  default     = null
  nullable    = true
}

variable "root_device_name" {
  description = "Root block device name used by the AMI"
  type        = string
  default     = "/dev/sda1"
}

variable "root_volume" {
  description = "Root EBS volume configuration"

  type = object({
    volume_type           = optional(string, "gp3")
    volume_size           = optional(number, 8)
    encrypted             = optional(bool, true)
    delete_on_termination = optional(bool, true)
  })

  default = {}
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 4
}

variable "health_check_grace_period" {
  description = "Seconds before ASG starts checking instance health"
  type        = number
  default     = 300
}

variable "default_instance_warmup" {
  description = "Seconds required for a new instance to warm up"
  type        = number
  default     = 300
}

variable "enable_cpu_scaling" {
  description = "Whether to enable CPU target tracking scaling"
  type        = bool
  default     = true
}

variable "cpu_target_value" {
  description = "Target average CPU utilization percentage"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags applied to ASG instances and volumes"
  type        = map(string)
  default     = {}
}
