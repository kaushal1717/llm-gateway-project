terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Uncomment for remote state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "llm-gateway/dev/terraform.tfstate"
  #   region         = "ap-south-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Secrets Manager - Generate and store secrets
module "secrets" {
  source = "../../modules/secrets"

  name        = local.name
  db_username = var.db_username
  tags        = local.common_tags
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  tags               = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "../../modules/security-groups"

  name           = local.name
  vpc_id         = module.vpc.vpc_id
  container_port = var.container_port
  tags           = local.common_tags
}

# RDS Module
module "rds" {
  source = "../../modules/rds"

  name              = local.name
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = module.security_groups.rds_security_group_id

  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  engine_version     = var.db_engine_version
  database_name      = var.db_name
  database_username  = module.secrets.db_username
  database_password  = module.secrets.db_password

  tags = local.common_tags
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  container_port        = var.container_port
  certificate_arn       = var.certificate_arn
  tags                  = local.common_tags
}

# ECS Module
module "ecs" {
  source = "../../modules/ecs"

  name                  = local.name
  aws_region            = var.aws_region
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_security_group_id
  target_group_arn      = module.alb.target_group_arn

  container_image    = var.container_image
  container_port     = var.container_port
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  desired_count      = var.desired_count
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity

  database_url       = module.rds.connection_string
  litellm_master_key = module.secrets.litellm_master_key
  secrets_arns       = module.secrets.secrets_arns

  tags = local.common_tags
}
