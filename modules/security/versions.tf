terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Allows 5.x patches/minor updates, but blocks major breaking changes (v6.0)
    }
  }
}