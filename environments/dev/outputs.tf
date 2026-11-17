output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "alb_sg_id" {
  value = module.security.alb_sg_id
}

output "ecs_sg_id" {
  value = module.security.ecs_sg_id
}

output "execution_role_arn" {
  value = module.iam.execution_role_arn
}

output "repository_url" {
  value = module.ecr.repository_url
}

output "repository_arn" {
  value = module.ecr.repository_arn
}

output "repository_name" {
  value = module.ecr.repository_name
}

output "target_group_arn" {
  value = module.alb.target_group_arn
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "alb_arn" {
  value = module.alb.alb_arn
}


output "cluster_name" {
  value = module.compute.cluster_name
}

output "cluster_arn" {
  value = module.compute.cluster_arn
}

output "service_name" {
  value = module.compute.service_name
}

output "service_id" {
  value = module.compute.service_id
}

output "task_defination_arn" {
  value = module.compute.task_defination_arn
}

output "autoscaling_target_id" {
  value = module.monitoring.autoscaling_target_id
}

output "autoscaling_policy_arn" {
  value = module.monitoring.autoscaling_policy_arn
}

output "memory_alarm_arn" {
  value = module.monitoring.memory_alarm_arn
}