# AWS ECS Service - Terraform Module

This is a Terraform module that creates an ECS (Elastic Container Service) service in AWS (Amazon Web Services). The module takes various inputs, such as the name and environment of the service, the cluster and subnets to use, and the container definitions. The container definitions include details such as the Docker image to use, the port mappings, and the desired count of containers. The module can also mount EFS volumes in the containers. Overall, this module simplifies the process of setting up an ECS service in AWS.

## How to use this module

```bash
module "vpc" {
  source      = "git::https://github.com/JManzur/terraform-aws-vpc.git?ref=v1.0.3"
  name_prefix = "JM"
  vpc_cidr    = "10.22.0.0/16"
  public_subnet_list = [
    {
      name    = "public"
      az      = 0
      newbits = 8
      netnum  = 10
    },
    {
      name    = "public"
      az      = 1
      newbits = 8
      netnum  = 11
    }
  ]
  private_subnet_list = [
    {
      name    = "private"
      az      = 0
      newbits = 8
      netnum  = 20
    },
    {
      name    = "private"
      az      = 1
      newbits = 8
      netnum  = 21
    }
  ]
}

module "ecs" {
  source = "git::https://github.com/JManzur/terraform-aws-ecs-fargate.git?ref=v1.0.0"

  name_prefix = var.name_prefix
  environment = var.environment

  capacity_providers                    = ["FARGATE"]
  enable_container_insights             = false
  include_execute_command_configuration = true
}

module "elb" {
  source = "git::https://github.com/JManzur/terraform-aws-elb.git?ref=v1.0.1"

  # Required variables:
  name_prefix             = var.name_prefix
  environment             = var.environment
  name_suffix             = var.name_suffix
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = module.vpc.vpc_cidr
  create_self_signed_cert = true
  elb_settings = [{
    name     = "demo"
    internal = false
    type     = "application"
    subnets  = module.vpc.private_subnets_ids
  }]
  access_logs_bucket = {
    enable_access_logs = false
    create_new_bucket  = false
  }
}

locals {
  service_name = "images-uploader"
  app_container = {
    name              = "images-uploader"
    port              = 8889
    image             = "jmanzur/images-uploader:latest"
    cpu               = 2048
    memory            = 4096
    health_check_path = "/status"
  }
  fargate_compute_capacity = {
    cpu    = 4096
    memory = 8192
  }
}

module "ecs_service" {
  source = "git::https://github.com/JManzur/terraform-aws-ecs-service.git?ref=v1.0.6"

  name_prefix              = var.name_prefix
  environment              = var.environment
  create_kms_key           = true
  kms_key_extra_role_arns  = []
  name_suffix              = var.name_suffix
  ecs_cluster              = module.ecs.ecs_cluster_identifiers["name"]
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr
  private_subnets          = module.vpc.private_subnets_ids
  service_name             = local.service_name
  desired_count            = 1
  fargate_compute_capacity = local.fargate_compute_capacity
  add_security_groups      = []
  appautoscaling_enabled   = false
  retain_task_definition   = false
  alb_target_groups = [
    {
      name     = local.service_name
      port     = local.app_container.port
      protocol = "HTTP"
      health = {
        path = local.app_container.health_check_path
      }
    }
  ]
  alb_listener_rules = [{
    name             = local.service_name
    listener_arn     = module.elb.https_listener_arns["demo"]
    healthcheck_path = "/"
    path_pattern     = ["*"]
  }]

  container_definitions = [
    {
      essential        = true
      name             = local.app_container.name
      image            = local.app_container.image
      log_routing      = "awslogs"
      cpu              = local.app_container.cpu
      memory           = local.app_container.memory
      secrets          = []
      environmentFiles = []
      portMappings     = []
      linuxParameters = {
        initProcessEnabled = true
      }
      portMappings = [
        {
          containerPort = local.app_container.port
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl --silent --fail localhost:${local.app_container.port}${local.app_container.health_check_path} || exit 1"]
        interval    = 60
        retries     = 3
        startPeriod = 10
        timeout     = 10
      }
    },
  ]

  depends_on = [
    module.ecs,
    module.elb
  ]
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
README.md updated successfully
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
