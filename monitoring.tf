# ECS Average CPU Utilization CloudWatch Metric Alarm:
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.cloudwatch_notifications.cpu_utilization_enabled ? 1 : 0

  alarm_name          = "ECS Service: ${aws_ecs_service.this.name} CPU Utilization"
  alarm_description   = "This metric monitors the Average CPU utilization of the ${aws_ecs_service.this.name} ECS service"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = var.cloudwatch_notifications.cpu_utilization_threshold # Default: 80
  treat_missing_data  = "missing"                                              # missing, ignore, breaching, notBreaching. https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html

  dimensions = {
    ClusterName = var.ecs_cluster,
    ServiceName = aws_ecs_service.this.name
  }

  ok_actions    = [try(var.cloudwatch_notifications.notification_topic_arn_ok_actions, null)]
  alarm_actions = [try(var.cloudwatch_notifications.notification_topic_arn_alarm_actions, null)]

  depends_on = [
    aws_ecs_service.this
  ]
}

# ECS Average Memory Utilization CloudWatch Metric Alarm:
resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  count = var.cloudwatch_notifications.memory_utilization_enabled ? 1 : 0

  alarm_name          = "ECS Service: ${aws_ecs_service.this.name} Memory Utilization"
  alarm_description   = "This metric monitors the Memory utilization of the ${aws_ecs_service.this.name} ECS service"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = var.cloudwatch_notifications.memory_utilization_threshold # Default: 80
  treat_missing_data  = "missing"                                                 # missing, ignore, breaching, notBreaching. https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html

  dimensions = {
    ClusterName = var.ecs_cluster,
    ServiceName = aws_ecs_service.this.name
  }

  ok_actions    = [try(var.cloudwatch_notifications.notification_topic_arn_ok_actions, null)]
  alarm_actions = [try(var.cloudwatch_notifications.notification_topic_arn_alarm_actions, null)]

  depends_on = [
    aws_ecs_service.this
  ]
}

resource "aws_opensearchserverless_access_policy" "data" {
  count = var.opensearch_serverless_collection_name != null ? 1 : 0

  name        = "${var.name_prefix}-${var.service_name}-policy"
  type        = "data"
  description = "Allow index access to ${var.name_prefix}-${var.service_name}"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index",
          Resource = [
            "index/${var.opensearch_serverless_collection_name}/*"
          ],
          Permission = [
            "aoss:CreateIndex",
            "aoss:WriteDocument",
            "aoss:UpdateIndex"
          ]
        }
      ],
      Principal = length(var.task_role_arn) == 0 ? [aws_iam_role.task_role[0].arn] : [var.task_role_arn]
    }
  ])

  depends_on = [
    aws_iam_role.task_role
  ]
}
