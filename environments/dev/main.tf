module "networking" {
  source = "../../modules/networking"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  environment          = var.environment

}

module "security" {
  source = "../../modules/security"

  vpc_id      = module.networking.vpc_id
  environment = var.environment
  app_port    = 5000
}

module "iam" {
  source = "../../modules/iam"

  environment = var.environment
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = "${var.environment}-flask-app"
  environment     = var.environment
}

module "alb" {
  source            = "../../modules/alb"
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  environment       = var.environment
  app_port          = 5000
}

module "compute" {
  source = "../../modules/compute"

  app_name           = "flask-app"
  environment        = var.environment
  container_cpu      = 256
  container_memory   = 512
  desired_count      = 2
  container_port     = 5000
  repository_url     = module.ecr.repository_url
  execution_role_arn = module.iam.execution_role_arn
  private_subnet_ids = module.networking.private_subnet_ids
  ecs_sg_id          = [module.security.ecs_sg_id]
  target_group_arn   = module.alb.target_group_arn
  image_tag          = "v1"

  depends_on = [
    module.alb,
    module.iam,
    module.networking,
    module.security
  ]
}

module "monitoring" {
  source = "../../modules/monitoring"

  cluster_name = module.compute.cluster_name
  service_name = module.compute.service_name
  environment  = var.environment

}