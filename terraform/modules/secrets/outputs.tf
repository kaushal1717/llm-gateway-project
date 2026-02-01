output "db_credentials_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "litellm_config_arn" {
  description = "ARN of the LiteLLM config secret"
  value       = aws_secretsmanager_secret.litellm_config.arn
}

output "litellm_config_name" {
  description = "Name of the LiteLLM config secret"
  value       = aws_secretsmanager_secret.litellm_config.name
}

output "db_username" {
  description = "Database username"
  value       = var.db_username
}

output "db_password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "litellm_master_key" {
  description = "LiteLLM master key"
  value       = "sk-${random_password.litellm_master_key.result}"
  sensitive   = true
}

output "secrets_arns" {
  description = "List of all secret ARNs for IAM policies"
  value = [
    aws_secretsmanager_secret.db_credentials.arn,
    aws_secretsmanager_secret.litellm_config.arn,
    aws_secretsmanager_secret.litellm_config_yaml.arn
  ]
}

output "litellm_config_yaml_arn" {
  description = "ARN of the LiteLLM config YAML secret"
  value       = aws_secretsmanager_secret.litellm_config_yaml.arn
}
