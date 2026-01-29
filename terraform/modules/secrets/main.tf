# Random password for database
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Random string for LiteLLM master key
resource "random_password" "litellm_master_key" {
  length  = 32
  special = false
}

# Secret for database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.name}/database-credentials"
  description             = "Database credentials for LiteLLM"
  recovery_window_in_days = 0 # For MVP - set to 7+ in production

  tags = merge(var.tags, {
    Name = "${var.name}-db-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
  })
}

# Secret for LiteLLM configuration
resource "aws_secretsmanager_secret" "litellm_config" {
  name                    = "${var.name}/litellm-config"
  description             = "LiteLLM configuration secrets"
  recovery_window_in_days = 0 # For MVP - set to 7+ in production

  tags = merge(var.tags, {
    Name = "${var.name}-litellm-config"
  })
}

resource "aws_secretsmanager_secret_version" "litellm_config" {
  secret_id = aws_secretsmanager_secret.litellm_config.id
  secret_string = jsonencode({
    master_key = "sk-${random_password.litellm_master_key.result}"
  })
}
