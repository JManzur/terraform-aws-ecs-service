# Get Account ID and Region:
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# Create a CMK for encrypting CloudWatch log groups:
resource "aws_kms_key" "cloudwatch_logs" {
  count = var.create_kms_key ? 1 : 0

  description             = "KMS key for CloudWatch log group encryption"
  deletion_window_in_days = 30    # Hardcoded to the maximum allowed value.
  multi_region            = false # Not required for CloudWatch log group encryption.
  enable_key_rotation     = true  # Hardcoded to enforce key rotation.

  tags = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}" }
}

# Allow the ECS agent to use the CMK:
resource "aws_kms_key_policy" "cloudwatch_logs" {
  count = var.create_kms_key ? 1 : 0

  key_id = aws_kms_key.cloudwatch_logs[0].id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Sid" : "Enable IAM User Permissions",
      "Effect" : "Allow",
      "Principal" : {
        "AWS" : concat(["arn:aws:iam::${local.account_id}:root"], var.kms_key_extra_role_arns)
      },
      "Action" : "kms:*",
      "Resource" : aws_kms_key.cloudwatch_logs[0].arn
      },
      {
        "Sid" : "Allow CloudWatch to encrypt logs",
        "Effect" : "Allow",
        "Principal" : { "Service" : "logs.${local.region}.amazonaws.com" },
        "Action" : [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ],
        "Resource" : aws_kms_key.cloudwatch_logs[0].arn
    }]
  })
}

# Create an alias for the CMK:
resource "aws_kms_alias" "cloudwatch_logs" {
  count = var.create_kms_key ? 1 : 0

  name          = lower("alias/${var.name_prefix}-${var.environment}-${var.service_name}")
  target_key_id = aws_kms_key.cloudwatch_logs[0].arn
}

# Create a CloudWatch log group and stream for the ECS service:
resource "aws_cloudwatch_log_group" "this" {
  for_each = { for app in var.container_definitions : app.name => app }

  name              = "/ecs/${var.name_prefix}-${var.environment}-${var.service_name}"
  retention_in_days = var.logs_retention

  /*
  In the next line, tfsec:ignore was added to ignore the false positive "aws-cloudwatch-log-group-customer-key" from tfsec.
  This false positive occurs because by default var.create_kms_key is set to false and the value of var.create_kms_key is an empty string.
  But in a real scenario, if the value of var.create_kms_key is set to false, the value of var.create_kms_key will be overwritten whit a valid KMS key ARN.
  */
  kms_key_id = var.create_kms_key ? aws_kms_key.cloudwatch_logs[0].arn : var.kms_key #tfsec:ignore:aws-cloudwatch-log-group-customer-key

  tags = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}" }

  depends_on = [
    aws_kms_key.cloudwatch_logs
  ]
}

resource "aws_cloudwatch_log_stream" "this" {
  for_each = { for app in var.container_definitions : app.name => app }

  name           = "${var.name_prefix}-${var.environment}-${var.service_name}"
  log_group_name = aws_cloudwatch_log_group.this[each.key].name
}

locals {
  container_definitions = [
    # If the log_routing is set to awsfirelens, then the logDriver is set to awsfirelens, else the logDriver is set to awslogs.
    for container in var.container_definitions : merge(container, {
      logConfiguration = (
        container.log_routing == "awsfirelens" ? {
          logDriver = "awsfirelens"
          options   = {}
        } :
        {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.this[container.name].name
            "awslogs-region"        = local.region
            "awslogs-stream-prefix" = "${var.name_prefix}-${var.environment}-${container.name}"
          }
        }
      )
    })
  ]
}

# Create the ECS Task Definition:
resource "aws_ecs_task_definition" "this" {
  family                   = var.service_name
  task_role_arn            = length(var.task_role_arn) == 0 ? aws_iam_role.task_role[0].arn : var.task_role_arn
  execution_role_arn       = length(var.execution_role_arn) == 0 ? aws_iam_role.execution_role[0].arn : var.task_role_arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"] # The value is hardcoded to FARGATE because EC2 is not supported by this module.
  skip_destroy             = var.retain_task_definition
  cpu                      = var.fargate_compute_capacity.cpu
  memory                   = var.fargate_compute_capacity.memory

  container_definitions = jsonencode(local.container_definitions)

  # Dynamic block for the EFS volume definitions:
  dynamic "volume" {
    for_each = length(var.efs_volumes) > 0 ? { for k, v in var.efs_volumes : v.volume_name => v } : {}

    content {
      name = volume.value.volume_name

      efs_volume_configuration {
        file_system_id          = volume.value.file_system_id
        root_directory          = try(volume.value.root_directory, null)
        transit_encryption      = "ENABLED" # Hardcoded to force encryption at rest: https://aquasecurity.github.io/tfsec/v1.28.1/checks/aws/efs/enable-at-rest-encryption/
        transit_encryption_port = volume.value.transit_encryption_port
        authorization_config {
          access_point_id = volume.value.access_point_id
          iam             = "ENABLED" # Hardcoded to force IAM authorization.
        }
      }
    }
  }

  # Dynamic block for the host volume definitions:
  dynamic "volume" {
    for_each = length(var.host_volumes) > 0 ? toset(var.host_volumes) : []

    content {
      name = volume.value.volume_name
    }
  }

  tags = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}" }

  lifecycle {
    create_before_destroy = true
  }
}

# AWS Security Group for the ECS Tasks:
resource "aws_security_group" "ecs_tasks" {
  count = length(var.security_group) == 0 ? 1 : 0

  name        = "${var.name_prefix}-${var.environment}-${var.service_name}-sg"
  description = "Allow inbound traffic from the load balancer to the ECS tasks"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = flatten([
      for app in var.container_definitions : [
        for port in try(app.portMappings, []) : {
          port     = port.containerPort
          protocol = port.protocol
        }
      ]
    ])

    content {
      description = "Allow inbound traffic to ${var.name_prefix}-${var.environment}-${var.service_name}"
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = [var.vpc_cidr]
    }
  }

  egress {
    description = "Allow outbound traffic from the ECS tasks to the internet"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-ec2-no-public-egress-sgr
  }

  tags = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}-sg" }
}

# ALB Target Group for the ECS Tasks:
resource "aws_lb_target_group" "ecs_tasks" {
  for_each = { for k, v in var.alb_target_groups : v.name => v }

  name        = "${var.name_prefix}-${var.environment}-${var.service_name}-tg"
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  tags = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}-tg" }

  health_check {
    healthy_threshold   = try(each.value.health.healthy_threshold, var.alb_health_check_config.healthy_threshold)
    unhealthy_threshold = try(each.value.health.unhealthy_threshold, var.alb_health_check_config.unhealthy_threshold)
    timeout             = try(each.value.health.timeout, var.alb_health_check_config.timeout)
    interval            = try(each.value.health.interval, var.alb_health_check_config.interval)
    matcher             = try(each.value.health.matcher, var.alb_health_check_config.matcher)
    protocol            = try(each.value.health.protocol, var.alb_health_check_config.protocol)
    path                = each.value.health.path
  }
}

# Create a listener rule to forward traffic to the ECS tasks:
resource "aws_lb_listener_rule" "ecs_tasks" {
  for_each = { for i, v in var.alb_listener_rules : i => v }

  listener_arn = each.value.listener_arn != null ? each.value.listener_arn : var.https_listener_arn
  priority     = lookup(each.value, "priority", null)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tasks[each.value.name].arn
  }

  dynamic "condition" {
    for_each = lookup(each.value, "path_pattern", null) != null ? [1] : []
    content {
      path_pattern {
        values = each.value.path_pattern
      }
    }
  }

  dynamic "condition" {
    for_each = lookup(each.value, "host_header", null) != null ? [1] : []
    content {
      host_header {
        values = each.value.host_header
      }
    }
  }
}

# Create the ECS Service:
resource "aws_ecs_service" "this" {
  name                   = "${var.name_prefix}-${var.environment}-${var.service_name}"
  cluster                = var.ecs_cluster
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE" # The value is hardcoded to FARGATE because EC2 is not supported by this module.
  platform_version       = var.fargate_platform_version
  enable_execute_command = var.enable_execute_command

  # Deployment configuration:
  deployment_controller {
    type = "ECS" # The value is hardcoded to ECS because CODE_DEPLOY is not supported by this module.
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Example: If desired_count is 2, then 2 more tasks will be created during the deployment, and when the new tasks are healthy, the 2 old tasks will be stopped.
  deployment_maximum_percent         = var.deployment_percent_config.maximum_percent
  deployment_minimum_healthy_percent = var.deployment_percent_config.minimum_healthy_percent

  # Network configuration:
  network_configuration {
    security_groups  = length(var.security_group) == 0 ? compact([aws_security_group.ecs_tasks[0].id, join(",", var.additional_security_groups)]) : [var.security_group]
    subnets          = var.private_subnets
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = aws_lb_target_group.ecs_tasks
    content {
      target_group_arn = load_balancer.value.arn
      container_name   = var.container_definitions[0].name
      container_port   = load_balancer.value.port
    }
  }

  tags = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}" }

  depends_on = [
    aws_security_group.ecs_tasks,
    aws_lb_target_group.ecs_tasks,
    aws_lb_listener_rule.ecs_tasks
  ]
}
