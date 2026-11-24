
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
# Terraform Apply - Backend, compute and IAM permissions
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

  statement {
    sid = "ManageExecutionRole"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:ListInstanceProfilesForRole"
    ]
    resources = [local.execution_role_arn]
  }

  statement {
    sid       = "ExecutionPolicyOnly"
    actions   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = [local.execution_role_arn]
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
    }
  }

  statement {
    sid       = "PassExecutionRoleToTasks"
    actions   = ["iam:PassRole"]
    resources = [local.execution_role_arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Also covers policy version changes, inline policies, permissions boundaries,
  # attachment changes and writes introduced by a future identity-policy grant.
  statement {
    sid    = "ProtectDeploymentAuthority"
    effect = "Deny"
    not_actions = [
      "iam:GetRole", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions",
      "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:ListRoleTags", "iam:ListPolicyTags"
    ]
    resources = [
      "${local.iam_arn}:role/GithubActions-Terraform-Apply-Role",
      "${local.iam_arn}:policy/GithubActionsTerraformApplyPolicy",
      "${local.iam_arn}:policy/GithubActionsTerraformApplyNetworkPolicy"
    ]
  }

  statement {
    actions = [
      "ecs:CreateCluster", "ecs:UpdateCluster", "ecs:UpdateClusterSettings", "ecs:DeleteCluster",
      "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService",
      "ecs:RegisterTaskDefinition", "ecs:TagResource", "ecs:UntagResource"
    ]
    resources = [
      "${local.ecs_arn}:cluster/flask-app-cluster-dev",
      "${local.ecs_arn}:service/flask-app-cluster-dev/flask-app-service-dev",
      "${local.ecs_arn}:task-definition/flask-app-dev:*"
    ]
  }

  # AWS defines no resource type for deregistration.
  statement {
    actions   = ["ecs:DeregisterTaskDefinition"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["ap-south-1"]
    }
  }

  statement {
    actions = [
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy", "logs:TagResource", "logs:UntagResource"
    ]
    resources = [local.log_group_arn, "${local.log_group_arn}:*"]
  }

  statement {
    actions = [
      "application-autoscaling:RegisterScalableTarget", "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:PutScalingPolicy", "application-autoscaling:DeleteScalingPolicy"
    ]
    resources = ["arn:aws:application-autoscaling:ap-south-1:207224908189:scalable-target/*"]
    condition {
      test     = "StringEquals"
      variable = "application-autoscaling:service-namespace"
      values   = ["ecs"]
    }
    condition {
      test     = "StringEquals"
      variable = "application-autoscaling:scalable-dimension"
      values   = ["ecs:service:DesiredCount"]
    }
  }

  statement {
    actions   = ["cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:TagResource", "cloudwatch:UntagResource"]
    resources = ["arn:aws:cloudwatch:ap-south-1:207224908189:alarm:flask-app-service-dev-memory-high"]
  }

}

# ------------------------------------------------
# Managed IAM Policy
# ------------------------------------------------

resource "aws_iam_policy" "terraform_apply_permissions" {
  name = "GithubActionsTerraformApplyPolicy"

  # Changing the historical description would replace this managed policy.
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
