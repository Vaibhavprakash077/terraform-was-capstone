output "autoscaling_target_id" {
  value = aws_appautoscaling_target.ecs_target.id
}

output "autoscaling_policy_arn" {
  value = aws_appautoscaling_policy.ecs_policy_cpu.arn
}


output "memory_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
}