output "target_groups_arn" {
  value       = { for k, v in aws_lb_target_group.ecs_tasks : k => v.arn }
  description = "Target Groups ARN"
}