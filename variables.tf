#######################################
# Required variables:
#######################################

variable "name_prefix" {
  type        = string
  description = "[REQUIRED] Used to name and tag resources."
}

variable "name_suffix" {
  description = "[REQUIRED] Suffix to use for naming in global resources (e.g. `main` or `dr`)"
  type        = string
}

variable "environment" {
  type        = string
  description = "[REQUIRED] The enviroment to deploy the resources, Used to name and tag resources."
}

variable "service_name" {
  type        = string
  description = "[REQUIRED] The name of the application."
}

variable "ecs_cluster" {
  type        = string
  description = "[REQUIRED] The ECS cluster name to deploy the service to."
}

variable "ecr_repository_arns" {
  type        = list(string)
  description = "[REQUIRED] The ARNs of the ECR repositories to pull images from."
  default     = [] # Empty list is allowed if using external images (e.g. Docker Hub)
}

variable "alb_target_groups" {
  description = <<EOF
  [REQUIRED] The ALB Target Group configuration for the ECS Service.
    - name (string): The name of the ALB target group.
    - port (number): The port to use for the ALB target group.
    - health (object): Health check configuration if we don't want to use a single config set for all target groups
      - path (string): URI to be requested
      - healthy_threshold (number): number of checks that should pass before considering target healthy
      - unhealthy_threshold (number): number of checks that should fail before considering target unhealthy
      - timeout (number): how long it should wait for a check to get a response (in seconds)
      - interval (number): seconds between checks
      - matcher (number): HTTP code that is expected in the response
      - protocol (string): protocol in which the check should be sent (HTTP, HTTPS, TCP, etc)
  EOF
  type = list(
    object({
      name = string
      port = number
      health = optional(object({
        path                = string
        healthy_threshold   = optional(number)
        unhealthy_threshold = optional(number)
        timeout             = optional(number)
        interval            = optional(number)
        matcher             = optional(number)
        protocol            = optional(string)
      }))
      protocol = string
    })
  )
}

variable "alb_listener_rules" {
  description = <<EOF
  [REQUIRED] The ALB configuration for the ECS Service.
    - name (string): The name of the ALB listener rule.
    - listener_arn (string): The ARN of the ALB listener to attach the service to.
    - tpc_port (number): The port to use for the ALB listener rule.
    - healthcheck_path (string): The path to use for the ALB healthcheck.
    - path_pattern (list(string)): List of path patterns to match.
    - host_header (list(string)): List of host headers to match.
    - priority (number): The priority for the rule between 1 and 50000.
  EOF
  type = list(object({
    name         = string
    listener_arn = optional(string)
    path_pattern = list(string)
    host_header  = optional(list(string))
    priority     = optional(number)
  }))
}

variable "desired_count" {
  type        = number
  description = "[REQUIRED] The number of instances of the task definition to place and keep running."
}

variable "container_definitions" {
  description = <<EOF
  [REQUIRED] Container definitions for the ECS Task Definition.

  Ref.: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#container_definitions

  - name (string): The name of the container.
  - image (string): The image URI to use for the container.
  - cpu (number): The number of cpu units reserved for the container.
  - memory (number): The hard limit (in MiB) of memory to present to the container.
  - essential (bool): If the container is essential.
  - dependsOn (list(object)): The dependencies defined for container startup and shutdown.
    - containerName (string): The name of the container to depend on.
    - condition (string): The dependency condition of the container. The following are the available conditions and their behavior:
      - START: This condition emulates the behavior of links and volumes today. It validates that a dependent container is started before permitting other containers to start.
      - COMPLETE: This condition validates that a dependent container runs to completion (exits) before permitting other containers to start. This can be useful for nonessential containers that run a script and then exit.
      - SUCCESS: This condition is the same as COMPLETE, but it also requires that the container exits with a zero status.
      - HEALTHY: This condition validates that the dependent container passes its Docker health check before permitting other containers to start. This requires that the dependent container has health checks configured. This condition is confirmed only at task startup.
  - memoryReservation (number): The soft limit (in MiB) of memory to reserve for the container.
  - portMappings (list(object)): The list of port mappings for the container.
    - containerPort (number): The port number on the container.
    - protocol (string): The protocol used for the port mapping.
  - user (string): The user name to use inside the container.
  - ulimits (list(object)): A list of ulimits to set in the container.
    - name (string): The type of the ulimit.
    - softLimit (number): The soft limit for the ulimit type.
    - hardLimit (number): The hard limit for the ulimit type.
  - entryPoint (list(string)): The entry point that is passed to the container.
  - command (list(string)): The command that is passed to the container.
  - environment (list(object)): The environment variables to pass to a container.
    - name (string): The name of the environment variable.
    - value (string): The value of the environment variable.
  - secrets (list(object)): The secrets to pass to the container.
    - name (string): The name of the secret.
    - valueFrom (string): The secret to expose to the container. The value is the ARN of the secret in the Secrets Manager.
  - mountPoints (list(object)): The mount points for data volumes in your container.
    - sourceVolume (string): The name of the volume to mount.
    - containerPath (string): The path on the container to mount the host volume at.
    - readOnly (bool): If this value is true, the container has read-only access to the volume; otherwise, false.
  - dockerLabels (map(string)): A key/value map of labels to add to the container.
  - healthCheck (object): The health check command and associated configuration parameters for the container.
    - command (list(string)): The command that the container runs to determine whether it is healthy.
    - interval (number): The time period in seconds between each health check execution.
    - retries (number): The number of times to retry a failed health check before the container is considered unhealthy.
    - startPeriod (number): The optional grace period in seconds that allows containers time to bootstrap before failed health checks count towards the maximum number of retries.
    - timeout (number): The time period in seconds to wait for a health check to succeed before it is considered a failure.
  - environmentFiles (list(object)): A list of files containing the environment variables to pass to a container.
    - value (string): The ARN of the Amazon S3 object containing the environment variable file.
    - type (string): The file type to use. The only supported value is s3.
  - firelensConfiguration (object): The FireLens configuration for the container.
    - type (string): The log router to use. The valid values are fluentd or fluentbit.
    - options (map(string)): The options to use when configuring the log router.
  - linuxParameters (object): Linux-specific modifications that are applied to the container, such as Linux kernel capabilities.
  EOF

  type = list(object({
    name        = string
    image       = string
    log_routing = string
    cpu         = number
    memory      = number
    essential   = optional(bool)
    dependsOn = optional(list(object({
      containerName = string
      condition     = string
    })))
    memoryReservation = optional(number)
    portMappings = list(object({
      containerPort = optional(number)
      protocol      = optional(string)
    }))
    user = optional(string)
    ulimits = optional(list(object({
      name      = string
      softLimit = number
      hardLimit = number
    })))
    entryPoint = optional(list(string))
    command    = optional(list(string))
    environment = optional(list(object({
      name  = string
      value = string
    })))
    secrets = list(object({
      name      = optional(string)
      valueFrom = optional(string)
    }))
    mountPoints = optional(list(object({
      containerPath = string
      sourceVolume  = string
      readOnly      = optional(bool)
    })))
    dockerLabels = optional(map(string))
    healthCheck = optional(object({
      command     = list(string)
      interval    = number
      retries     = number
      startPeriod = number
      timeout     = number
    }))
    environmentFiles = list(object({
      value = optional(string)
      type  = optional(string)
    }))
    firelensConfiguration = optional(object({
      type    = string
      options = optional(map(string))
    }))
    linuxParameters = optional(object({
      capabilities = optional(object({
        add  = optional(list(string))
        drop = optional(list(string))
      }))
      devices = optional(list(object({
        hostPath      = string
        containerPath = string
        permissions   = optional(list(string))
      })))
      initProcessEnabled = optional(bool)
      maxSwap            = optional(number)
      sharedMemorySize   = optional(number)
      swappiness         = optional(number)
      tmpfs = optional(list(object({
        containerPath = string
        size          = number
        mountOptions  = optional(list(string))
      })))
    }))
  }))

  validation {
    condition = alltrue([
      for container_def in var.container_definitions :
      can(regex("^(awslogs|awsfirelens)$", container_def.log_routing))
    ])
    error_message = "Invalid log_routing. Must be one of the following: awslogs, awsfirelens."
  }

  validation {
    condition = alltrue([
      for container_def in var.container_definitions :
      container_def.cpu >= 256 && container_def.cpu <= 16384
    ])
    error_message = "CPU value must be between 256 and 16384."
  }

  validation {
    condition = alltrue([
      for container_def in var.container_definitions :
      container_def.memory >= 512 && container_def.memory <= 114441
    ])
    error_message = "Memory value must be between 512 and 114441."
  }

  validation {
    condition = alltrue([
      for container_def in var.container_definitions : (
        container_def.cpu == 256 && container_def.memory >= 512 && container_def.memory <= 2048 ||
        container_def.cpu == 512 && container_def.memory >= 1024 && container_def.memory <= 4096 ||
        container_def.cpu == 1024 && container_def.memory >= 2048 && container_def.memory <= 8192 ||
        container_def.cpu == 2048 && container_def.memory >= 4096 && container_def.memory <= 16384 ||
        container_def.cpu == 4096 && container_def.memory >= 8192 && container_def.memory <= 30720 ||
        container_def.cpu == 8192 && container_def.memory >= 16384 && container_def.memory <= 61440 ||
        container_def.cpu == 16384 && container_def.memory >= 30720 && container_def.memory <= 114441
      )
    ])
    error_message = "Invalid Memory and CPU combination. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html for more information."
  }

  validation {
    condition = alltrue([
      for container_def in var.container_definitions :
      can(index(container_def, "portMappings")) ? alltrue([
        for port_mapping in container_def.portMappings :
        can(index(port_mapping, "protocol")) ? lower(port_mapping.protocol) == "tcp" || lower(port_mapping.protocol) == "udp" : false
      ]) : true
    ])
    error_message = "If portMappings is defined, then protocol must be defined and the value must be either tcp or udp in lower case."
  }
}

variable "vpc_id" {
  description = "[REQUIRED] The VPC ID"
  type        = string

  validation {
    condition = (
      can(regex("^vpc-[a-z0-9]", var.vpc_id)) && length(substr(var.vpc_id, 4, 17)) == 8 ||
      can(regex("^vpc-[a-z0-9]", var.vpc_id)) && length(substr(var.vpc_id, 4, 17)) == 17
    )
    error_message = "Invalid VPC ID. Must be of format 'vpc-xxxxxxxx' and length of eather 8 or 17 (after the vpc- prefix )."
  }
}

variable "vpc_cidr" {
  description = "[REQUIRED] The VPC CIDR block, Required format: '0.0.0.0/0'"
  type        = string

  validation {
    condition     = try(cidrhost(var.vpc_cidr, 0), null) != null
    error_message = "The CIDR block is invalid. Must be of format '0.0.0.0/0'."
  }
}

variable "private_subnets" {
  type        = list(string)
  description = "[REQUIRED] A list of private subnets to place the ECS Service in."
}

#######################################
# Optional variables:
#######################################

variable "appautoscaling_enabled" {
  description = "[OPTIONAL] Whether to enable App Autoscaling for the ECS Service."
  type        = bool
  default     = true
}

variable "appautoscaling_config" {
  description = <<EOF
  [REQUIRED] The App Autoscaling configuration for the ECS Service.
    - min_capacity (number): The minimum capacity of the ECS Service.
    - max_capacity (number): The maximum capacity of the ECS Service.
    - metric_type (string): The metric type to use for the App Autoscaling configuration. Must be one of the following: ECSServiceAverageCPUUtilization, ECSServiceAverageMemoryUtilization, ALBRequestCountPerTarget.
    - target_value (number): The target value for the metric type in percent.
    - disable_scale_in (bool): Whether to disable scale in for the ECS Service.
    - scale_in_cooldown (number): The cooldown in seconds before allowing another scale in activity.
    - scale_out_cooldown (number): The cooldown in seconds before allowing another scale out activity.
  EOF
  type = object({
    min_capacity       = number
    max_capacity       = number
    metric_type        = string
    target_value       = number
    disable_scale_in   = bool
    scale_in_cooldown  = optional(number)
    scale_out_cooldown = number
  })

  default = {
    min_capacity       = 2
    max_capacity       = 6
    metric_type        = "ECSServiceAverageCPUUtilization"
    target_value       = 85
    disable_scale_in   = false
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }

  validation {
    condition     = can(regex("^(ECSServiceAverageCPUUtilization|ECSServiceAverageMemoryUtilization|ALBRequestCountPerTarget)", var.appautoscaling_config.metric_type))
    error_message = "Invalid metric_type. Must be one of the following: ECSServiceAverageCPUUtilization, ECSServiceAverageMemoryUtilization, ALBRequestCountPerTarget."
  }
}

variable "additional_policy_arn" {
  type        = string
  description = "[OPTIONAL] A list of additional policy ARNs to attach to the ECS Service."
  default     = ""
}

variable "execution_role_arn" {
  type        = string
  description = "[OPTIONAL] ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume."
  default     = ""
}

variable "task_role_arn" {
  type        = string
  description = "[OPTIONAL] ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services."
  default     = ""
}

variable "security_group" {
  type        = string
  description = "[OPTIONAL] The security group to use for the ECS Service."
  default     = ""
}

variable "alb_health_check_config" {
  description = <<EOF
  [OPTIONAL] The health check configuration for the ECS Service.
    - healthy_threshold (number): The number of consecutive health checks successes required before moving the ECS Service to an Healthy state.
    - unhealthy_threshold (number): The number of consecutive health check failures required before moving the ECS Service to an Unhealthy state.
    - timeout (number): The amount of time, in seconds, during which no response means a failed health check.
    - interval (number): The approximate amount of time, in seconds, between health checks of an individual target.
    - matcher (string): The HTTP codes to use when checking for a successful response from a target.
    - protocol (string): The protocol to use when performing health checks on the ECS Service. Must be one of the following: HTTP, HTTPS, TCP, TLS.
  EOF
  type = object({
    healthy_threshold   = number
    unhealthy_threshold = number
    timeout             = number
    interval            = number
    matcher             = string
    protocol            = string
  })

  default = {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    matcher             = "200"
    protocol            = "HTTP"
  }

  validation {
    condition     = can(regex("^(200|200-299|200|301|302|200-399|200-499|200-599)", var.alb_health_check_config.matcher))
    error_message = "Invalid matcher. Must be one of the following: 200, 200-299, 200, 301, 302, 200-399, 200-499, 200-599."
  }

  validation {
    condition     = can(regex("^(HTTP|HTTPS|TCP|TLS)", var.alb_health_check_config.protocol))
    error_message = "Invalid protocol. Must be one of the following: HTTP, HTTPS, TCP, TLS."
  }
}

variable "efs_volumes" {
  description = <<EOF
  [OPTIONAL] A list of EFS volumes to mount to the ECS Service.
    - file_system_id (string): The ID of the EFS file system.
    - access_point_id (string): The ID of the EFS access point.
    - root_directory (string): The root directory to mount to the ECS Service.
  EOF

  type = list(object({
    volume_name             = string
    root_directory          = optional(string)
    file_system_id          = string
    access_point_id         = string
    read_only               = bool
    transit_encryption_port = optional(number, 2999)
  }))

  default = []

  validation {
    condition = alltrue([
      for efs_volume in var.efs_volumes :
      can(regex("^fs-[a-z0-9]", efs_volume.file_system_id)) && length(substr(efs_volume.file_system_id, 3, 17)) == 8 ||
      can(regex("^fs-[a-z0-9]", efs_volume.file_system_id)) && length(substr(efs_volume.file_system_id, 3, 17)) == 17
    ])
    error_message = "Invalid EFS file_system_id. Must be of format 'fs-xxxxxxxx' and length of eather 8 or 17 (after the fs- prefix )."
  }

  validation {
    condition = alltrue([
      for efs_volume in var.efs_volumes :
      can(regex("^fsap-[a-z0-9]", efs_volume.access_point_id)) && length(substr(efs_volume.access_point_id, 5, 22)) == 8 ||
      can(regex("^fsap-[a-z0-9]", efs_volume.access_point_id)) && length(substr(efs_volume.access_point_id, 5, 22)) == 17
    ])
    error_message = "Invalid EFS access_point_id. Must be of format 'fsap-xxxxxxxx' and length of eather 8 or 18 (after the fsap- prefix )."
  }
}

variable "host_volumes" {
  description = <<EOF
  [OPTIONAL] A list of host volumes to mount to the ECS Service.
    - name (string): The name of the volume to mount to the ECS Service. It needs to match the name of the volume in the container definition.
  EOF

  type = list(object({
    volume_name = string
  }))

  default = []
}

variable "deployment_percent_config" {
  description = <<EOF
  [OPTIONAL] Deployment configuration for the ECS Service.

  Ref.: https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_DeploymentConfiguration.html

  - maximum_percent (number): The upper limit (as a percentage of the service's desiredCount) of the number of running tasks that can be running in a service during a deployment.
  - minimum_healthy_percent (number): The lower limit (as a percentage of the service's desiredCount) of the number of running tasks that must remain running and healthy in a service during a deployment.
  EOF
  type = object({
    maximum_percent         = optional(number)
    minimum_healthy_percent = optional(number)
  })

  default = {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }
}

variable "enable_execute_command" {
  type        = bool
  description = "[OPTIONAL] If true, enables ECS ExecuteCommand feature on the ECS Service." # Ref.: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html
  default     = true
}

variable "fargate_platform_version" {
  type        = string
  description = "[OPTIONAL] The platform version on which to run your service. Only applicable for launch_type set to FARGATE. Defaults to LATEST."
  default     = "LATEST"

  validation {
    condition     = can(regex("^(1.4.0|1.3.0|LATEST)$", var.fargate_platform_version))
    error_message = "The platform version must be one of 1.4.0, 1.3.0, or LATEST."
  }
}

variable "logs_retention" {
  description = "[OPTIONAL] The number of days to retain logs for. Default is 90 days."
  type        = number
  default     = 90

  validation {
    condition = (
      var.logs_retention == 0 ||
      var.logs_retention == 1 ||
      var.logs_retention == 3 ||
      var.logs_retention == 5 ||
      var.logs_retention == 7 ||
      var.logs_retention == 14 ||
      var.logs_retention == 30 ||
      var.logs_retention == 60 ||
      var.logs_retention == 90 ||
      var.logs_retention == 120 ||
      var.logs_retention == 150 ||
      var.logs_retention == 180 ||
      var.logs_retention == 365 ||
      var.logs_retention == 400 ||
      var.logs_retention == 545 ||
      var.logs_retention == 731 ||
      var.logs_retention == 1827 ||
      var.logs_retention == 3653
    )
    error_message = "The value must be one of the followings: 0,1,3,5,7,14,30,60,90,120,150,180,365,400,545,731,1827,3653."
  }
}

variable "fargate_compute_capacity" {
  description = <<EOF
  [OPTIONAL] The amount (in GB) of memory used by the task. 
  Ref.: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html

  Example:
  {
    cpu    = 256
    memory = 512
  }
  EOF
  type = object({
    cpu    = number
    memory = number
  })

  default = {
    cpu    = 1024
    memory = 2048
  }

  validation {
    condition = (
      (var.fargate_compute_capacity.cpu == 256 && var.fargate_compute_capacity.memory >= 512 && var.fargate_compute_capacity.memory <= 2048) ||
      (var.fargate_compute_capacity.cpu == 512 && var.fargate_compute_capacity.memory >= 1024 && var.fargate_compute_capacity.memory <= 4096) ||
      (var.fargate_compute_capacity.cpu == 1024 && var.fargate_compute_capacity.memory >= 2048 && var.fargate_compute_capacity.memory <= 8192) ||
      (var.fargate_compute_capacity.cpu == 2048 && var.fargate_compute_capacity.memory >= 4096 && var.fargate_compute_capacity.memory <= 16384) ||
      (var.fargate_compute_capacity.cpu == 4096 && var.fargate_compute_capacity.memory >= 16384 && var.fargate_compute_capacity.memory <= 30720) ||
      (var.fargate_compute_capacity.cpu == 8192 && var.fargate_compute_capacity.memory >= 16384 && var.fargate_compute_capacity.memory <= 61440) ||
      (var.fargate_compute_capacity.cpu == 16384 && var.fargate_compute_capacity.memory >= 32768 && var.fargate_compute_capacity.memory <= 122880)
    )
    error_message = "Invalid Memory and CPU combination. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html for more information."
  }
}

variable "retain_task_definition" {
  description = "[OPTIONAL] If true, the task definition will not be deleted when the service is destroyed, this is also useful for manual rollbacks."
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "[OPTIONAL] If true, a KMS key will be created and used to encrypt the CloudWatch log group."
  type        = bool
  default     = false
}

variable "kms_key_extra_role_arns" {
  description = "[REQUIRED] The ARNs of the IAM roles that should be able to use the KMS key."
  type        = list(string)
  default     = [] # Empty list is allowed if var.create_kms_key is set to false
}

variable "kms_key" {
  description = "[OPTIONAL] The ARN of the KMS key to use to encrypt the CloudWatch log group."
  type        = string
  default     = "" # Null is allowed if var.create_kms_key is set to false
}

variable "https_listener_arn" {
  description = "[OPTIONAL] The ARN of the HTTPS listener to attach the service to."
  type        = string
  default     = "" # Null is allowed if var.alb_listener_rules.listener_arn is set
}

variable "additional_security_groups" {
  type        = list(any)
  description = "[OPTIONAL] list of additional security groups"
  default     = [] # Empty list is allowed
}