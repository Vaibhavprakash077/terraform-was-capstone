resource "aws_security_group" "ALB" {
  name        = "${var.environment}-ALB-sg"
  description = "security group for ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-ALB-sg"
    Environment = "${var.environment}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ALB" {
  security_group_id = aws_security_group.ALB.id

  description = "allow inbound HTTP traffic"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ALB" {
  security_group_id            = aws_security_group.ALB.id
  referenced_security_group_id = aws_security_group.ECS.id

  description = "Allow all outbound internet traffic"
  ip_protocol = "tcp"
  from_port   = var.app_port
  to_port     = var.app_port
}





resource "aws_security_group" "ECS" {
  name        = "${var.environment}-ECS-sg"
  description = "security group for ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-ECS-sg"
    Environment = "${var.environment}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ECS" {
  security_group_id            = aws_security_group.ECS.id
  referenced_security_group_id = aws_security_group.ALB.id
  description                  = "allow inbound HTTP traffic"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port

}

resource "aws_vpc_security_group_egress_rule" "ECS" {
  security_group_id = aws_security_group.ECS.id

  description = "Allow all outbound internet traffic"
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443

}




