output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "service_id" {
  value = aws_ecs_service.app.id
}

output "task_defination_arn" {
  value = aws_ecs_task_definition.app.arn
}