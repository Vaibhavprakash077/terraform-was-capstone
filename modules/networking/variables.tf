variable "vpc_cidr" {
  type        = string
  description = "The primary IPv4 CIDR block for the Virtual Private Cloud (e.g., 10.0.0.0/16)."
  # No default: Left required so the root module explicitly dictates network sizing.
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "A list of IPv4 CIDR blocks for public subnets, mapped to individual Availability Zones."
  # No default: Required to prevent accidental overlapping IP allocations.
  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRS are required."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "A list of IPv4 CIDR blocks for private subnets (used by backend services or ECS Fargate)."
  # No default: Required to ensure correct container and internal routing space.
  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnet CIDRS are required."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "A list of target AWS Availability Zones (e.g., ['us-east-1a', 'us-east-1b']) for multi-AZ redundancy."
  # No default: Required to align subnets with specific regional datacenters.
  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly two Availability Zones are required."
  }
}

variable "environment" {
  type        = string
  description = "The deployment stage (e.g., dev, staging, prod) used for resource naming prefixes and tagging."
}
