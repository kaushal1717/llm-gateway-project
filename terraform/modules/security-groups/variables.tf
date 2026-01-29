variable "name" {
  description = "Name prefix for security group resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 4000
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
