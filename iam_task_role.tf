/*
ECS Task IAM Roles:
  ECS tasks can have IAM roles assigned to them, which are used to grant permissions to the containers in the task.
  This is useful for granting permissions to access other AWS services from your task, such as S3 or DynamoDB.
  Example 1: If you want to access EFS from your task, you need to grant the task an IAM role with the appropriate permissions.
  Example 2: If you want to access S3 from your task using the AWS SDK or the AWS CLI, you need to grant the task an IAM role with the appropriate permissions.
*/

data "aws_iam_policy_document" "task_role" {
  count = length(var.task_role_arn) == 0 ? 1 : 0

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

  # OpenSearch Policy: Needed for firelens logging driver:
  # Temporal: Will be changed for a dynamic block when the OpenSearch module is ready.
  statement {
    sid    = "ESAccess"
    effect = "Allow"
    actions = [
      "es:ESHttpDelete",
      "es:ESHttpGet",
      "es:ESHttpHead",
      "es:ESHttpPost",
      "es:ESHttpPut"
    ]
    resources = ["arn:aws:es:${local.region}:${local.account_id}:domain/*"]
  }

  # CloudWatch Logs Policy: Needed for firelens logging driver:
  # Temporal: Will be changed for a dynamic block when the OpenSearch module is ready.
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

data "aws_iam_policy_document" "task_role_trust" {
  count = length(var.task_role_arn) == 0 ? 1 : 0

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

resource "aws_iam_policy" "task_role" {
  count = length(var.task_role_arn) == 0 ? 1 : 0

  name   = "${var.name_prefix}-${var.environment}-${var.service_name}-task-role-policy-${var.name_suffix}"
  path   = "/"
  policy = data.aws_iam_policy_document.task_role[0].json
  tags   = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}-task-role-policy-${var.name_suffix}" }
}

resource "aws_iam_role" "task_role" {
  count = length(var.task_role_arn) == 0 ? 1 : 0

  name               = "${var.name_prefix}-${var.environment}-${var.service_name}-task-role-${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.task_role_trust[0].json
  tags               = { Name = "${var.name_prefix}-${var.environment}-${var.service_name}-task-role-${var.name_suffix}" }
}

resource "aws_iam_role_policy_attachment" "task_role" {
  count = length(var.task_role_arn) == 0 ? 1 : 0

  role       = aws_iam_role.task_role[0].name
  policy_arn = aws_iam_policy.task_role[0].arn
}

# Attach additional policy to task role if var.additional_policy_arn and var.task_role_arn are not empty:
resource "aws_iam_role_policy_attachment" "additional_policy" {
  count = length(var.task_role_arn) == 0 && length(var.additional_policy_arn) >= 20 ? 1 : 0

  role       = aws_iam_role.task_role[0].name
  policy_arn = try(var.additional_policy_arn, null)
}