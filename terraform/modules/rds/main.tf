# DB Subnet Group for RDS
resource "aws_db_subnet_group" "main" {
  name        = "${var.name}-db-subnet-group"
  description = "Database subnet group for LiteLLM"
  subnet_ids  = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-db-subnet-group"
  })
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.name}-postgres"

  # Engine configuration
  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true

  # Database configuration
  db_name  = var.database_name
  username = var.database_username
  password = var.database_password
  port     = 5432

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false # CRITICAL: Not publicly accessible
  multi_az               = false # Single AZ for MVP cost optimization

  # Backup and maintenance
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # MVP settings
  skip_final_snapshot       = true # For MVP only - change in production
  deletion_protection       = false # For MVP only - enable in production
  auto_minor_version_upgrade = true

  # Performance Insights (free tier available)
  performance_insights_enabled = true
  performance_insights_retention_period = 7

  # Parameter group for connection limits
  parameter_group_name = aws_db_parameter_group.main.name

  tags = merge(var.tags, {
    Name = "${var.name}-postgres"
  })
}

# Custom Parameter Group for db.t4g.micro connection management
resource "aws_db_parameter_group" "main" {
  name        = "${var.name}-postgres-params"
  family      = "postgres${split(".", var.engine_version)[0]}"
  description = "Custom parameter group for LiteLLM PostgreSQL"

  # Optimize for db.t4g.micro limited resources
  parameter {
    name  = "max_connections"
    value = "80" # Conservative limit for t4g.micro
  }

  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/32768}" # ~128MB for 1GB instance
  }

  tags = merge(var.tags, {
    Name = "${var.name}-postgres-params"
  })
}
