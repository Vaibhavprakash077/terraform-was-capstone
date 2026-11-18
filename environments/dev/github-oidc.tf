data "aws_iam_policy_document" "github_oidc_trust" {
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

    # Condition 2: Restrict strictly to your repository and main branch
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:Vaibhavprakash077@137153293/terraform-was-capstone@1462040058:ref:refs/heads/main"
      ]
    }

  }
}

resource "aws_iam_role" "github_ecr_push" {
  name               = "GithubActions-ECR-Push-Role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust.json
}

data "aws_iam_policy_document" "ecr_permissions" {
  # Allow getting the auth token needed to docker login to ECR
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Allow pushing and managing images in your ECR repository
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage"
    ]
    resources = [
      "arn:aws:ecr:ap-south-1:207224908189:repository/dev-flask-app"
    ]
  }
}

resource "aws_iam_policy" "ecr_push_policy" {
  name   = "GitHubActionsECRPushPolicy"
  policy = data.aws_iam_policy_document.ecr_permissions.json
}

# Attach the permissions policy to the GitHub Actions IAM role
resource "aws_iam_role_policy_attachment" "attach_ecr_push" {
  role       = aws_iam_role.github_ecr_push.name
  policy_arn = aws_iam_policy.ecr_push_policy.arn
}