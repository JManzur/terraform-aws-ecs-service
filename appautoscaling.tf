resource "aws_appautoscaling_target" "this" {
  count = var.appautoscaling_enabled ? 1 : 0

  service_namespace  = "ecs" # Hardcoded value because it's the only valid value for ECS services
  resource_id        = "service/${var.ecs_cluster}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount" # Hardcoded value because it's the only valid value for ECS services

  min_capacity = var.appautoscaling_config.min_capacity
  max_capacity = var.appautoscaling_config.max_capacity
}

resource "aws_appautoscaling_policy" "this" {
  count = var.appautoscaling_enabled ? 1 : 0

  name               = "${var.name_prefix}-${var.environment}-${var.service_name}-autoscaling-policy"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = var.appautoscaling_config.metric_type
    }
    target_value       = var.appautoscaling_config.target_value
    disable_scale_in   = var.appautoscaling_config.disable_scale_in
    scale_in_cooldown  = var.appautoscaling_config.disable_scale_in ? null : var.appautoscaling_config.scale_in_cooldown
    scale_out_cooldown = var.appautoscaling_config.scale_out_cooldown
  }
}