/*
ECS Execution Role Definition:
  This is the role that the ECS service will assume to perform its actions.
  It needs to be able to create and update the ECS service, and to create and update the CloudWatch log group and stream.
  It also needs to be able to pull images from the ECR repositories.
  If you're using an existing role, you can skip this section.
*/

# Create a list of all the ARNs that are used in the container definitions:
locals {
  ssm_parameters_arns = distinct(flatten([
    for app in var.container_definitions :
    [for secret in app.secrets : can(regex("arn:aws:ssm:[^:]+:[^:]+:parameter/.*", secret.valueFrom)) ? secret.valueFrom : null]
  ]))

  secrets_arns = distinct(flatten([
    for app in var.container_definitions :
    [for secret in app.secrets : can(regex("arn:aws:secretsmanager:[^:]+:[^:]+:secret:.*", secret.valueFrom)) ? secret.valueFrom : null]
  ]))

  environment_files_s3_arn = distinct(flatten([
    for app in var.container_definitions :
    [for env_file in app.environmentFiles : can(regex("arn:aws:s3:::.*", env_file.environmentFiles)) ? env_file.environmentFiles : null]
  ]))

  efs_access_points_rw = [
    for vol in var.efs_volumes : vol.access_point_id if vol.read_only == false
  ]

  efs_access_points_ro = [
    for vol in var.efs_volumes : vol.access_point_id if vol.read_only == true
  ]
}

data "aws_iam_policy_document" "execution_role" {
  count = length(var.execution_role_arn) == 0 ? 1 : 0

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy"
    ]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:/ecs/${var.name_prefix}-${var.environment}-*"]
  }

  statement {
    sid    = "ECR"
    effect = "Allow"
    actions = [
      "ecr:DescribeRepositories",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = length(var.ecr_repository_arns) > 0 ? var.ecr_repository_arns : ["*"]
  }

  statement {
    sid    = "ECS"
    effect = "Allow"
    actions = [
      "ecs:CreateService",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:ListContainerInstances",
      "ecs:UpdateService"
    ]
    resources = [
      "arn:aws:ecs:${local.region}:${local.account_id}:cluster/${var.ecs_cluster}",
      "arn:aws:ecs:${local.region}:${local.account_id}:service/${var.ecs_cluster}/${var.name_prefix}-${var.environment}-${var.service_name}}"
    ]
  }

  statement {
    sid    = "ECSTaskActions"
    effect = "Allow"
    actions = [
      "ecs:StopTask",
      "ecs:DescribeTasks"
    ]
    resources = ["arn:aws:ecs:${local.region}:${local.account_id}:task-definition/${var.service_name}:*"]
  }

  /* Dynamic statements blocks for additional policies that may be required by container definitions. */
  dynamic "statement" {
    for_each = length(compact(local.ssm_parameters_arns)) > 0 ? [1] : []
    content {
      sid    = "SSMParameterStore"
      effect = "Allow"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParameterHistory",
        "ssm:GetParametersByPath",
        "ssm:DescribeParameters"
      ]
      resources = compact(local.ssm_parameters_arns)
    }
  }

  dynamic "statement" {
    for_each = length(compact(local.secrets_arns)) > 0 ? [1] : []
    content {
      sid    = "AWSSecretsManager"
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets"
      ]
      resources = compact(local.secrets_arns)
    }
  }

  dynamic "statement" {
    for_each = length(compact(local.environment_files_s3_arn)) > 0 ? [1] : []
    content {
      sid    = "S3EnvironmentFiles"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetObjectTagging"
      ]
      resources = compact(local.environment_files_s3_arn)
    }
  }

  dynamic "statement" {
    for_each = length(local.efs_access_points_rw) > 0 ? [1] : []
    content {
      sid    = "EFSAccessPointsRW"
      effect = "Allow"
      actions = [
        "elasticfilesystem:Client*"
      ]
      resources = [
        for id in local.efs_access_points_rw : "arn:aws:elasticfilesystem:${local.region}:${local.account_id}:file-system/${id}"
      ]
    }
  }

  dynamic "statement" {
    for_each = length(local.efs_access_points_ro) > 0 ? [1] : []
    content {
      sid    = "EFSAccessPointsRO"
      effect = "Allow"
      actions = [
        "elasticfilesystem:ClientMount"
      ]
      resources = [
        for id in local.efs_access_points_ro : "arn:aws:elasticfilesystem:${local.region}:${local.account_id}:file-system/${id}"
      ]
    }
  }

  /* The following actions require 'All Resources' and do not support resource level permissions */

  statement {
    sid    = "PublicECRPullAccess"
    effect = "Allow"
    actions = [
      "ecr-public:GetAuthorizationToken",
      "ecr-public:BatchCheckLayerAvailability",
      "ecr-public:GetRepositoryCatalogData",
      "ecr-public:DescribeImages",
      "ecr-public:DescribeRepositories",
      "ecr-public:GetRepositoryPolicy"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TaskDefinitions"
    effect = "Allow"
    actions = [
      "ecs:ListTaskDefinitions",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:RegisterTaskDefinition"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "GetAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECSExecuteCommand"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "execution_role_trust" {
  count = length(var.execution_role_arn) == 0 ? 1 : 0

  statement {
    sid     = "ECSAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "execution_role" {
  count = length(var.execution_role_arn) == 0 ? 1 : 0

  name   = "${var.name_prefix}-${var.environment}-${var.service_name}-execution-role-policy-${var.name_suffix}"
  path   = "/"
  policy = data.aws_iam_policy_document.execution_role[0].json
  tags   = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}-execution-role-policy-${var.name_suffix}" }
}

resource "aws_iam_role" "execution_role" {
  count = length(var.execution_role_arn) == 0 ? 1 : 0

  name               = "${var.name_prefix}-${var.environment}-${var.service_name}-execution-role-${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.execution_role_trust[0].json
  tags               = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}-execution-role-${var.name_suffix}" }
}

resource "aws_iam_role_policy_attachment" "execution_role" {
  count = length(var.execution_role_arn) == 0 ? 1 : 0

  role       = aws_iam_role.execution_role[0].name
  policy_arn = aws_iam_policy.execution_role[0].arn
}