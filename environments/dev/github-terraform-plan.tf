resource "aws_iam_role" "github_terraform_plan" {
  name               = "GithubActions-Terraform-Plan-Role"
  assume_role_policy = data.aws_iam_policy_document.github_terraform_plan_trust.json
  description        = "IAM role for GitHub Actions Terraform planning"
}

data "aws_iam_policy_document" "terraform_plan_permissions" {
  statement {
    sid     = "ListStateBucket"
    actions = ["s3:ListBucket"]
    resources = [
      "arn:aws:s3:::tfstate-vaibhav-capstone-207224908189-aps1"
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "terraform-aws-capstone/dev/terraform.tfstate",
        "terraform-aws-capstone/dev/terraform.tfstate.tflock"
      ]
    }
  }

  statement {
    sid     = "ReadState"
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::tfstate-vaibhav-capstone-207224908189-aps1/terraform-aws-capstone/dev/terraform.tfstate"
    ]
  }

  statement {
    sid = "ManageStateLock"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::tfstate-vaibhav-capstone-207224908189-aps1/terraform-aws-capstone/dev/terraform.tfstate.tflock"
    ]
  }

  statement {
    sid = "ReadManagedAWSResources"

    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "ecs:Describe*",
      "ecs:List*",
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "application-autoscaling:Describe*",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource",
      "iam:GetRole",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
      "iam:ListPolicyTags"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform_plan_permissions" {
  name   = "GithubActionsTerraformPlanPolicy"
  policy = data.aws_iam_policy_document.terraform_plan_permissions.json
}

resource "aws_iam_role_policy_attachment" "terraform_plan_attachment" {
  role       = aws_iam_role.github_terraform_plan.name
  policy_arn = aws_iam_policy.terraform_plan_permissions.arn
}

data "aws_iam_policy_document" "github_terraform_plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::207224908189:oidc-provider/token.actions.githubusercontent.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:Vaibhavprakash077@137153293/terraform-was-capstone@1462040058:environment:terraform-plan"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:ref"
      values   = ["refs/heads/main"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:workflow"
      values   = ["Terraform Plan"]
    }
  }
}