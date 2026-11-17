terraform {
  backend "s3" {
    bucket       = "tfstate-vaibhav-capstone-207224908189-aps1"
    key          = "terraform-aws-capstone/dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}