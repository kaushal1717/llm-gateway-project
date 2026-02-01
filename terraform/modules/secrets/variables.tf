variable "name" {
  description = "Name prefix for secrets"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "litellm"
}

variable "litellm_config_yaml" {
  description = "LiteLLM configuration YAML content"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
