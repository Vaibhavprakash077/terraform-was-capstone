output "alb_sg_id" {
  value = aws_security_group.ALB.id
}

output "ecs_sg_id" {
  value = aws_security_group.ECS.id
}