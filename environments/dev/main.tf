module "networking" {
  source    = "../../modules/networking"
  providers = { aws = aws.network }

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  environment          = var.environment

}

module "security" {
  source    = "../../modules/security"
  providers = { aws = aws.network }

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

# The immutable release tag is the operator-facing identifier. ECS pulls its digest.
data "aws_ecr_image" "release" {
  repository_name = module.ecr.repository_name
  image_tag       = "7dc368b0eb5c17f6f9391898734571141271cac9"

  lifecycle {
    postcondition {
      condition     = self.image_digest == "sha256:d9161cf30b0f4a3d3b5c9f7bc14ced69cf7d6126b8df4900906847c983d05fe1"
      error_message = "The ECR tag must resolve to the reviewed release digest."
    }
  }
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
  image_tag          = data.aws_ecr_image.release.image_tag
  image_digest       = data.aws_ecr_image.release.image_digest

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