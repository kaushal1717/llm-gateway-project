variable "name" {
  description = "Name prefix for secrets"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "litellm"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
