variable "name" {
  description = "Name prefix for ECS resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "container_image" {
  description = "Docker image for LiteLLM"
  type        = string
  default     = "ghcr.io/berriai/litellm:main-latest"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 4000
}

variable "task_cpu" {
  description = "CPU units for the task (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 3
}

variable "database_url" {
  description = "PostgreSQL connection string"
  type        = string
  sensitive   = true
}

variable "litellm_master_key" {
  description = "LiteLLM master API key"
  type        = string
  sensitive   = true
}

variable "secrets_arns" {
  description = "List of Secrets Manager ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "container_secrets" {
  description = "List of secrets to inject into the container"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
