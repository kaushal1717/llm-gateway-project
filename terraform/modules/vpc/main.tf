module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = true # Cost optimization for MVP
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Tags for ECS/EKS discovery
  public_subnet_tags = {
    "Type" = "Public"
  }

  private_subnet_tags = {
    "Type" = "Private"
  }

  tags = var.tags
}
