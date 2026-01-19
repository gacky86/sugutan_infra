# ID プロバイダを作成
data "http" "github_actions_openid_configuration" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

data "tls_certificate" "github_actions" {
  url = jsondecode(data.http.github_actions_openid_configuration.response_body).jwks_uri
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.github_actions.certificates[*].sha1_fingerprint
}

# IAM ロールを作成
data "aws_iam_policy_document" "frontend_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn] # ID プロバイダの ARN
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # 特定のリポジトリの特定のブランチからのみ認証を許可する場合
    # condition {
    #   test     = "StringEquals"
    #   variable = "token.actions.githubusercontent.com:sub"
    #   values   = ["repo:<GitHubユーザー名>/<GitHubリポジトリ名>:ref:refs/heads/<ブランチ名>"]
    # }
    # 特定のリポジトリの全てのワークフローから認証を許可する場合
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:gacky86/sugutan_frontend:*"]
    }
  }
}

resource "aws_iam_role" "frontend" {
  name               = "oidc-frontend-role"
  assume_role_policy = data.aws_iam_policy_document.frontend_assume_role_policy.json
}

# フロントエンドデプロイ用の権限を定義
data "aws_iam_policy_document" "frontend_deploy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:ListBucket", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::prd-sugutan-frontend",
      "arn:aws:s3:::prd-sugutan-frontend/*"
    ]
  }
  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = ["arn:aws:cloudfront::178795222462:distribution/E1B4AHWUZHUAYN"]
  }
}

resource "aws_iam_role_policy" "frontend_deploy" {
  name   = "frontend-deploy-policy"
  role   = aws_iam_role.frontend.id
  policy = data.aws_iam_policy_document.frontend_deploy.json
}


# バックエンド（Rails）用IAMロール
resource "aws_iam_role" "backend_deploy" {
  name = "oidc-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          # すでに作成済みのプロバイダのARNを参照
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Condition = {
          StringLike = {
            # バックエンドのリポジトリ名を指定
            "token.actions.githubusercontent.com:sub" = "repo:gacky86/sugutan_backend:*"
          }
        }
      }
    ]
  })
}

# バックエンドデプロイ用の権限（ECR & ECS）
resource "aws_iam_role_policy" "backend_deploy" {
  name = "backend-deploy-policy"
  role = aws_iam_role.backend_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. ECRへのログイン・プッシュ権限
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*" # ログインは全リソースに対して必要
      },
      # 2. ECSタスク定義の取得と更新
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      # 3. ECSサービスの更新（デプロイ実行）
      {
        Effect = "Allow"
        Action = ["ecs:UpdateService", "ecs:DescribeServices"]
        Resource = "arn:aws:ecs:ap-northeast-1:178795222462:service/prd-sugutan-api/sugutan-api"
      },
      # 4. パスロール権限（デプロイ時にECSに権限を渡すために必要）
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "arn:aws:iam::178795222462:role/prd-sugutan-api-execution-role",
          "arn:aws:iam::178795222462:role/prd-sugutan-api-task-role"
        ]
      }
    ]
  })
}
