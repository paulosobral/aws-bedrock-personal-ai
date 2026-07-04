# Módulo IAM Role para Amazon Bedrock
# Cria user dedicado e role com permissões mínimas para Bedrock

# IAM User dedicado para Bedrock
resource "aws_iam_user" "bedrock_user" {
  name = "${var.role_name}-user"
  path = "/bedrock/"
  tags = merge(
    var.tags,
    {
      Name = "${var.role_name}-user"
    }
  )
}

# Access Key para o IAM User
resource "aws_iam_access_key" "bedrock_user_key" {
  user = aws_iam_user.bedrock_user.name
}

# Política inline para o user assumir a role + AWS Marketplace
resource "aws_iam_user_policy" "assume_role_policy" {
  name = "assume-bedrock-role"
  user = aws_iam_user.bedrock_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.bedrock_role.arn
      },
      {
        Effect = "Allow"
        Action = [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Subscribe",
          "aws-marketplace:Unsubscribe",
          "aws-marketplace:GetAgreementTerms"
        ]
        Resource = "*"
      }
    ]
  })
}

# Política de confiança - apenas o user dedicado pode assumir
resource "aws_iam_role" "bedrock_role" {
  name                 = var.role_name
  description          = "Role IAM para acesso ao Amazon Bedrock - user dedicado"
  assume_role_policy   = data.aws_iam_policy_document.assume_role_policy.json
  permissions_boundary = var.permission_boundary_arn != null ? var.permission_boundary_arn : null
  tags = merge(
    var.tags,
    {
      Name = var.role_name
    }
  )
}

# Política de confiança - limitada ao user dedicado
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.bedrock_user.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalArn"
      values   = [aws_iam_user.bedrock_user.arn]
    }
  }
}

# Política inline com permissões Bedrock restritas
resource "aws_iam_role_policy" "bedrock_permissions" {
  name   = "bedrock-model-access"
  role   = aws_iam_role.bedrock_role.id
  policy = data.aws_iam_policy_document.bedrock_permissions.json
}

# Política de permissões Bedrock - least privilege
data "aws_iam_policy_document" "bedrock_permissions" {
  statement {
    sid    = "ListFoundationModels"
    effect = "Allow"

    actions = [
      "bedrock:ListFoundationModels",
      "bedrock:ListInferenceProfiles"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AWSMarketplaceAccess"
    effect = "Allow"

    actions = [
      "aws-marketplace:ViewSubscriptions",
      "aws-marketplace:Subscribe",
      "aws-marketplace:Unsubscribe",
      "aws-marketplace:GetAgreementTerms"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "InvokeBedrockModels"
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid    = "DenyNonBedrockIAM"
    effect = "Deny"

    actions = [
      "iam:*"
    ]

    resources = ["*"]

    condition {
      test     = "StringNotLike"
      variable = "aws:RequestedAction"
      values = [
        "iam:PassRole"
      ]
    }
  }
}

# Permission Boundary - impede permissões fora do escopo Bedrock
resource "aws_iam_policy" "bedrock_permission_boundary" {
  count       = var.create_permission_boundary ? 1 : 0
  name        = "${var.role_name}-boundary"
  description = "Permission boundary para role Bedrock - limita permissões ao escopo Bedrock"
  policy      = data.aws_iam_policy_document.permission_boundary.json
  tags        = var.tags
}

data "aws_iam_policy_document" "permission_boundary" {
  statement {
    sid    = "AllowBedrockActions"
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModels"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DenyNonBedrockActions"
    effect = "Deny"

    not_actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModels"
    ]

    resources = ["*"]
  }
}

# CloudTrail para auditoria de chamadas Bedrock
resource "aws_cloudtrail" "bedrock_audit" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "${var.role_name}-trail"
  s3_bucket_name                = var.cloudtrail_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  tags = var.tags
}
