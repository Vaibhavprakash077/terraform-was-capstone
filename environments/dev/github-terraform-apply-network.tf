locals {
  iam_arn            = "arn:aws:iam::207224908189"
  execution_role_arn = "${local.iam_arn}:role/dev-ecs_execution_role"
  ecs_arn            = "arn:aws:ecs:ap-south-1:207224908189"
  log_group_arn      = "arn:aws:logs:ap-south-1:207224908189:log-group:/ecs/flask-app-dev"
  elb_arn            = "arn:aws:elasticloadbalancing:ap-south-1:207224908189"
  ec2_resources = [for kind in [
    "vpc", "subnet", "internet-gateway", "elastic-ip", "natgateway",
    "route-table", "security-group", "security-group-rule"
  ] : "arn:aws:ec2:ap-south-1:207224908189:${kind}/*"]

  # Bind each create to its new resource type. A request tag on a new SG
  # rule must never authorize changes to an unrelated parent security group.
  creates_by_type = {
    vpc                 = ["ec2:CreateVpc"]
    subnet              = ["ec2:CreateSubnet"]
    internet-gateway    = ["ec2:CreateInternetGateway"]
    elastic-ip          = ["ec2:AllocateAddress"]
    natgateway          = ["ec2:CreateNatGateway"]
    route-table         = ["ec2:CreateRouteTable"]
    security-group      = ["ec2:CreateSecurityGroup"]
    security-group-rule = ["ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress"]
  }
  network_create = flatten(values(local.creates_by_type))
}

# Keep both customer-managed policies below IAM's 6,144-character limit.
data "aws_iam_policy_document" "terraform_apply_network" {
  dynamic "statement" {
    for_each = local.creates_by_type
    content {
      actions   = statement.value
      resources = ["arn:aws:ec2:ap-south-1:207224908189:${statement.key}/*"]
      condition {
        test     = "StringEquals"
        variable = "aws:RequestTag/CapstoneStack"
        values   = ["terraform-aws-capstone-dev"]
      }
    }
  }

  statement {
    sid       = "TagDuringNetworkCreation"
    actions   = ["ec2:CreateTags"]
    resources = local.ec2_resources
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = [for action in local.network_create : trimprefix(action, "ec2:")]
    }
  }

  # Multi-resource creates also authorize the existing VPC, subnet, EIP or SG.
  statement {
    sid = "ManageOwnedNetwork"
    actions = concat(local.network_create, [
      "ec2:ModifyVpcAttribute", "ec2:ModifySubnetAttribute", "ec2:DeleteVpc", "ec2:DeleteSubnet",
      "ec2:AttachInternetGateway", "ec2:DetachInternetGateway", "ec2:DeleteInternetGateway",
      "ec2:DeleteNatGateway", "ec2:ReleaseAddress", "ec2:DeleteRouteTable",
      "ec2:CreateRoute", "ec2:ReplaceRoute", "ec2:DeleteRoute", "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable", "ec2:ReplaceRouteTableAssociation", "ec2:DeleteSecurityGroup",
      "ec2:ModifySecurityGroupRules", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags", "ec2:DeleteTags"
    ])
    resources = local.ec2_resources
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/CapstoneStack"
      values   = ["terraform-aws-capstone-dev"]
    }
  }

  statement {
    actions = [
      "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets", "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:CreateListener", "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyListenerAttributes", "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "${local.elb_arn}:loadbalancer/app/dev-app-alb/*",
      "${local.elb_arn}:listener/app/dev-app-alb/*/*",
      "${local.elb_arn}:targetgroup/dev-app-tg/*"
    ]
  }
}

resource "aws_iam_policy" "terraform_apply_network" {
  name        = "GithubActionsTerraformApplyNetworkPolicy"
  description = "Dev capstone VPC, security group and ALB lifecycle"
  policy      = data.aws_iam_policy_document.terraform_apply_network.json
  tags        = aws_iam_role.github_terraform_apply.tags
}

resource "aws_iam_role_policy_attachment" "terraform_apply_network" {
  role       = aws_iam_role.github_terraform_apply.name
  policy_arn = aws_iam_policy.terraform_apply_network.arn
}
