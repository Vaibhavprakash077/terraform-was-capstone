variable "container_cpu" {
  type = number
}

variable "container_memory" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "private_subnet_ids" {
  type = list(string)
}


variable "target_group_arn" {
  type = string
}

variable "app_name" {
  type = string
}

variable "container_port" {
  type = number
}

variable "execution_role_arn" {
  type = string
}

variable "repository_url" {
  type = string
}

variable "environment" {
  type = string
}

variable "ecs_sg_id" {
  type = list(string)
}

variable "image_tag" {
  type = string
}

variable "image_digest" {
  type        = string
  default     = null
  description = "Immutable release digest. Existing tag-only callers may omit it."
}
