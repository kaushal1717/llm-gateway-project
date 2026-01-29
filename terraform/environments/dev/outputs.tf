# ============================================
# Required Outputs - RDS Endpoint and ALB DNS
# ============================================

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.endpoint
}

output "alb_dns_name" {
  description = "ALB DNS name - Use this to access LiteLLM"
  value       = module.alb.alb_dns_name
}

# ============================================
# Additional Useful Outputs
# ============================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "litellm_api_url" {
  description = "LiteLLM API URL"
  value       = "http://${module.alb.alb_dns_name}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS"
  value       = module.ecs.log_group_name
}

# Sensitive outputs
output "litellm_master_key" {
  description = "LiteLLM master API key - use this for admin operations"
  value       = module.secrets.litellm_master_key
  sensitive   = true
}

output "database_connection_string" {
  description = "Database connection string"
  value       = module.rds.connection_string
  sensitive   = true
}
