variable "vpc_cidr" {
  type        = string
  description = "The primary IPv4 CIDR block for the Virtual Private Cloud (e.g., 10.0.0.0/16)."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "A list of IPv4 CIDR blocks for public subnets, mapped to individual Availability Zones."
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}


variable "private_subnet_cidrs" {
  type        = list(string)
  description = "A list of IPv4 CIDR blocks for private subnets (used by backend services or ECS Fargate)."
  default = [
    "10.0.10.0/24",
    "10.0.11.0/24"
  ]

}

variable "availability_zones" {
  type        = list(string)
  description = "A list of target AWS Availability Zones (e.g., ['us-east-1a', 'us-east-1b']) for multi-AZ redundancy."
  default = [
    "ap-south-1a",
    "ap-south-1b"
  ]


}
variable "environment" {
  type        = string
  description = "The deployment stage (e.g., dev, staging, prod) used for resource naming prefixes and tagging."
  default     = "dev"
}

