
# ---------------------------------------------
# GitHub Actions - Terraform Apply
# AWS OIDC trust policy
# ---------------------------------------------

data "aws_iam_policy_document" "github_terraform_apply_trust" {

  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::207224908189:oidc-provider/token.actions.githubusercontent.com"
      ]
    }

    # AWS STS audience
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to this repository and environment
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:Vaibhavprakash077@137153293/terraform-was-capstone@1462040058:environment:terraform-apply"
      ]
    }

    # Only runs originating from main
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:ref"
      values   = ["refs/heads/main"]
    }

    # Dedicated workflow identity
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:workflow"
      values   = ["Terraform Apply"]
    }
  }
}

# ---------------------------------------------
# Dedicated IAM role for Terraform Apply
# ---------------------------------------------

resource "aws_iam_role" "github_terraform_apply" {
  name = "GithubActions-Terraform-Apply-Role"

  description = "Approval-gated Terraform deployment role for the DevOps capstone"

  assume_role_policy = data.aws_iam_policy_document.github_terraform_apply_trust.json

  max_session_duration = 3600

  tags = {
    Project     = "terraform-aws-capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Purpose     = "GitHubActionsTerraformApply"
  }
}

# ------------------------------------------------
# Terraform Apply - Initial Permissions Policy
# ------------------------------------------------

data "aws_iam_policy_document" "terraform_apply_permissions" {

  # Reuse the existing Terraform Plan read permissions.
  source_policy_documents = [
    data.aws_iam_policy_document.terraform_plan_permissions.json
  ]

  # Allow updating only this environment's state file.
  statement {
    sid    = "WriteDevTerraformState"
    effect = "Allow"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::tfstate-vaibhav-capstone-207224908189-aps1/terraform-aws-capstone/dev/terraform.tfstate"
    ]
  }
}

# ------------------------------------------------
# Managed IAM Policy
# ------------------------------------------------

resource "aws_iam_policy" "terraform_apply_permissions" {
  name = "GithubActionsTerraformApplyPolicy"

  description = "Initial backend and read permissions for Terraform Apply"

  policy = data.aws_iam_policy_document.terraform_apply_permissions.json

  tags = {
    Project     = "terraform-aws-capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------
# Attach Policy to Dedicated Apply Role
# ------------------------------------------------

resource "aws_iam_role_policy_attachment" "terraform_apply_attachment" {
  role       = aws_iam_role.github_terraform_apply.name
  policy_arn = aws_iam_policy.terraform_apply_permissions.arn
}
