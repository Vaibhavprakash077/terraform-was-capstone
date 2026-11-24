provider "aws" {
  region = "ap-south-1"

}

# EC2 resource IDs are assigned on creation. The deployment policy uses this
# ownership tag for networking and security, including their standalone rules.
provider "aws" {
  alias  = "network"
  region = "ap-south-1"

  default_tags {
    tags = { CapstoneStack = "terraform-aws-capstone-dev" }
  }
}
