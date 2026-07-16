resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  update_default_version = true

  vpc_security_group_ids = var.security_group_ids

  # The module receives plain user_data and encodes it for EC2.
  user_data = var.user_data != null ? base64encode(var.user_data) : null

  # Only create this block when an IAM instance profile is provided.
  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile_name != null ? [1] : []

    content {
      name = var.iam_instance_profile_name
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = var.root_device_name

    ebs {
      volume_type           = var.root_volume.volume_type
      volume_size           = var.root_volume.volume_size
      encrypted             = var.root_volume.encrypted
      delete_on_termination = var.root_volume.delete_on_termination
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      {
        Name = "${var.name}-instance"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = "${var.name}-volume"
      }
    )
  }
}


# ASG

resource "aws_autoscaling_group" "this" {
  name = "${var.name}-asg"

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  default_instance_warmup = var.default_instance_warmup

  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns

  health_check_type = (
    length(var.target_group_arns) > 0
    ? "ELB"
    : "EC2"
  )

  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = var.default_instance_warmup
      skip_matching          = true
    }
  }

  dynamic "tag" {
    for_each = merge(
      var.tags,
      {
        Name = "${var.name}-instance"
      }
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}


resource "aws_autoscaling_policy" "cpu" {
  count = var.enable_cpu_scaling ? 1 : 0

  name                   = "${var.name}-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  estimated_instance_warmup = var.default_instance_warmup

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.cpu_target_value
  }
}