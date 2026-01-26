# ======= ECS クラスタ、キャパシティプロバイダ =======
resource "aws_ecs_cluster" "sugutan_api" {
  name = "${var.stage}-sugutan-api"
}
resource "aws_ecs_cluster_capacity_providers" "sugutan_api" {
  capacity_providers = ["FARGATE"]
  cluster_name = aws_ecs_cluster.sugutan_api.name
}

# ======= ECS タスク実行ロール =======
# SSMパラメータストアについてのデータソース

data "aws_ssm_parameter" "sugutan_api_db_name" {
  name  = "/sugutan-api/${var.stage}/rds/db_name"
}
data "aws_ssm_parameter" "sugutan_api_db_username" {
  name  = "/sugutan-api/${var.stage}/rds/db_username"
}
data "aws_ssm_parameter" "sugutan_api_db_password" {
  name  = "/sugutan-api/${var.stage}/rds/db_password"
}
data "aws_ssm_parameter" "sugutan_api_rails_master_key" {
  name  = "/sugutan-api/${var.stage}/rds/rails_master_key"
}
data "aws_ssm_parameter" "sugutan_api_smtp_username" {
  name  = "/sugutan-api/${var.stage}/smtp/smtp_username"
}
data "aws_ssm_parameter" "sugutan_api_smtp_password" {
  name  = "/sugutan-api/${var.stage}/smtp/smtp_password"
}
data "aws_ssm_parameter" "sugutan_api_gemini_api_key" {
  name  = "/sugutan-api/${var.stage}/gemini/gemini_api_key"
}
data "aws_ssm_parameter" "sugutan_api_gmail_user_name" {
  name  = "/sugutan-api/${var.stage}/gmail/gmail_user_name"
}
data "aws_ssm_parameter" "sugutan_api_gmail_password" {
  name  = "/sugutan-api/${var.stage}/gmail/gmail_password"
}
# 信頼関係ポリシー
data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
      type = "Service"
    }
  }
}
# ECRやCloudWatch Logsのアクションを許可するAWSマネージドポリシー
data "aws_iam_policy" "managed_ecs_task_execution" {
  name = "AmazonECSTaskExecutionRolePolicy"
}
# タスク実行ロールにアタッチするインラインポリシー
# 起動時にSSMパラメータストアから環境変数を取得するのでその許可を記述
data "aws_iam_policy_document" "ecs_task_execution" {
  statement {
    effect = "Allow"
    actions   = ["ssm:GetParameters", "ssm:GetParameter"]
    # 参照するパラメータストアを記述
    resources = [
      aws_ssm_parameter.sugutan_api_db_host.arn,
      data.aws_ssm_parameter.sugutan_api_db_name.arn,
      data.aws_ssm_parameter.sugutan_api_db_username.arn,
      data.aws_ssm_parameter.sugutan_api_db_password.arn,
      data.aws_ssm_parameter.sugutan_api_rails_master_key.arn,
      data.aws_ssm_parameter.sugutan_api_smtp_username.arn,
      data.aws_ssm_parameter.sugutan_api_smtp_password.arn,
      data.aws_ssm_parameter.sugutan_api_gemini_api_key.arn,
      data.aws_ssm_parameter.sugutan_api_gmail_user_name.arn,
      data.aws_ssm_parameter.sugutan_api_gmail_password.arn
    ]
  }
}
# IAMロールを記述
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.stage}-sugutan-api-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}
# IAMロールにAWSマネージドポリシーをアタッチ
resource "aws_iam_role_policy_attachments_exclusive" "ecs_task_execution_managed_policy" {
  policy_arns = [data.aws_iam_policy.managed_ecs_task_execution.arn]
  role_name   = aws_iam_role.ecs_task_execution_role.name
}
# IAMロールにインラインポリシーをアタッチ
resource "aws_iam_role_policy" "ecs_task_execution_inline_policy" {
  name = "${var.stage}-sugutan-api-ecs-task-execution-policy"
  role = aws_iam_role.ecs_task_execution_role.name
  policy = data.aws_iam_policy_document.ecs_task_execution.json
}

# ======= ECS タスクロール =======
# タスクの実行中に必要なAWSリソースへのアクションの許可をアタッチ
# この例では、ECS Fargateにターミナルからログインできる機能(ECS Exec)を使うためのSSMのアクションに許可を付与

# 信頼関係ポリシー
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
      type = "Service"
    }
  }
}
# タスクロールにアタッチするインラインポリシー
# ECS Execの実行に必要なアクションを許可
data "aws_iam_policy_document" "ecs_task" {
  statement {
    effect = "Allow"
    actions   = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    # 参照するパラメータストアを記述
    resources = ["*"]
  }
}
# タスクロール
resource "aws_iam_role" "ecs_task" {
  name               = "${var.stage}-sugutan-api-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}
# タスクロールにインラインポリシーをアタッチ
resource "aws_iam_role_policy" "ecs_task_inline_policy" {
  name = "${var.stage}-sugutan-api-ecs-task-policy"
  policy = data.aws_iam_policy_document.ecs_task.json
  role   = aws_iam_role.ecs_task.name
}

# ======= VPC, Subnetの情報の取得 =======
locals {
  vpc_name = "${var.stage}-vpc-tf" # VPCのモジュールで定義したnameと一致すること
}

# VPC情報の照会
data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = [local.vpc_name]
  }
}
# Subnet情報の照会
data "aws_subnets" "public" {
  filter {
    name = "tag:Name"
    values = [
      "${local.vpc_name}-public-ap-northeast-1a",
      "${local.vpc_name}-public-ap-northeast-1c"
    ]
  }
}
data "aws_subnets" "private" {
  filter {
    name = "tag:Name"
    values = [
      "${local.vpc_name}-intra-ap-northeast-1a",
      "${local.vpc_name}-intra-ap-northeast-1c"
    ]
  }
}

# ======= セキュリティグループ =======
# ALB用のセキュリティグループ
resource "aws_security_group" "alb" {
  name        = "${var.stage}-sugutan-api-alb"
  vpc_id      = data.aws_vpc.this.id
}
# ECS Fargateインスタンス用のセキュリティグループ
resource "aws_security_group" "ecs_instance" {
  name        = "${var.stage}-sugutan-api-ecs-instance"
  vpc_id      = data.aws_vpc.this.id
}
# RDS用のセキュリティグループ
resource "aws_security_group" "rds" {
  name        = "${var.stage}-sugutan-api-rds"
  vpc_id      = data.aws_vpc.this.id
}
# ALB用のセキュリティグループ インバウンドルール
# 任意のIPアドレスからHTTPポート(80)への接続を許可
resource "aws_vpc_security_group_ingress_rule" "lb_from_http" {
  security_group_id = aws_security_group.alb.id
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}
# 任意のIPアドレスからHTTPSポート(443)への接続を許可
resource "aws_vpc_security_group_ingress_rule" "lb_from_https" {
  security_group_id = aws_security_group.alb.id
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}
# ALB用のセキュリティグループ アウトバウンドルール
# 全てのアウトバウンド通信を許可
resource "aws_vpc_security_group_egress_rule" "lb_to_all" {
  security_group_id = aws_security_group.alb.id
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
# ECS Fargate インスタンス用のセキュリティグループ　インバウンドルール
# ALBから3000番ポートへの接続を許可
resource "aws_vpc_security_group_ingress_rule" "ecs_instance_from_lb" {
  security_group_id = aws_security_group.ecs_instance.id
  ip_protocol = "tcp"
  from_port   = 3000
  to_port     = 3000
  # ALB用のセキュリティグループがアタッチされたENIからの通信を許可
  referenced_security_group_id = aws_security_group.alb.id
}
# ECS Fargate インスタンス用のセキュリティグループ アウトバウンドルール
# 全てのアウトバウンド通信を許可
# AWSアクションをリクエストするエンドポイント(ECR, SSM、RDSなど)と通信できるようにするため
resource "aws_vpc_security_group_egress_rule" "ecs_instance_to_all" {
  security_group_id = aws_security_group.ecs_instance.id
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
# RDS用セキュリティグループ　インバウンドルール
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id = aws_security_group.rds.id
  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
  referenced_security_group_id = aws_security_group.ecs_instance.id
}
# RDS用セキュリティグループ　アウトバウンドルール
resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ======= ALB =======
# ALB本体
resource "aws_lb" "sugutan_api" {
  name               = "${var.stage}-sugutan-api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  enable_deletion_protection = true
}
# ALBのターゲットグループ
# 3000番ポートで通信を受け付ける
resource "aws_lb_target_group" "sugutan_api" {
  name = "sugutan-api"
  port = 3000
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = data.aws_vpc.this.id
  health_check {
    path = "/health"
    protocol = "HTTP"
    matcher = "200"
    interval = 30
  }
}
# ALBのリスナー
# 80番ポートで受け付けたリクエストをターゲットグループに転送
# ？ここもHTTPS用に改造もしくは追加が必要？
# もしHTTPS用なら、docの方が近いかも
# HTTPSリスナー
resource "aws_lb_listener" "sugutan_api_https" {
  load_balancer_arn = aws_lb.sugutan_api.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.sugutan_api.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sugutan_api.arn
  }
}
resource "aws_lb_listener" "sugutan_api" {
  load_balancer_arn = aws_lb.sugutan_api.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ======= ECS =======
# リージョンの問い合わせ
data "aws_region" "current" {}

# ECRリポジトリの問い合わせ(nameは定義したECRと一致させるごと)
data "aws_ecr_repository" "sugutan_api" {
  name = "${var.stage}-sugutan-api"
}

# ECSタスクのロググループ
resource "aws_cloudwatch_log_group" "sugutan_api" {
  name = "/ecs/${var.stage}-sugutan-api"
  retention_in_days = 90
}

# コンテナ定義をlocalsで定義しておく
# aws_ecs_task_definitionのcontainer_definition以外からも参照できる
locals {
  container_definitions = {
    sugutan_api = {
      name = "sugutan-api"
      # 環境変数はSSMパラメータから取得
      secrets = [
        {
          name = "DB_HOST"
          valueFrom = aws_ssm_parameter.sugutan_api_db_host.arn
        },
        {
          name = "DB_NAME"
          valueFrom = data.aws_ssm_parameter.sugutan_api_db_name.arn
        },
        {
          name = "DB_USERNAME"
          valueFrom = data.aws_ssm_parameter.sugutan_api_db_username.arn
        },
        {
          name = "DB_PASSWORD"
          valueFrom = data.aws_ssm_parameter.sugutan_api_db_password.arn
        },
        {
          name = "RAILS_MASTER_KEY"
          valueFrom = data.aws_ssm_parameter.sugutan_api_rails_master_key.arn
        },
        {
          name = "SMTP_USERNAME"
          valueFrom = data.aws_ssm_parameter.sugutan_api_smtp_username.arn
        },
        {
          name = "SMTP_PASSWORD"
          valueFrom = data.aws_ssm_parameter.sugutan_api_smtp_password.arn
        },
        {
          name = "GEMINI_API_KEY"
          valueFrom = data.aws_ssm_parameter.sugutan_api_gemini_api_key.arn
        },
        {
          name = "GMAIL_USER_NAME"
          valueFrom = data.aws_ssm_parameter.sugutan_api_gmail_user_name.arn
        },
        {
          name = "GMAIL_PASSWORD"
          valueFrom = data.aws_ssm_parameter.sugutan_api_gmail_password.arn
        },
      ]
      essential = true
      # ECRリポジトリのデータソースを参照
      image = "${data.aws_ecr_repository.sugutan_api.repository_url}:latest"
      environment = [
        { name = "RAILS_ENV", value = "production" },
        { name = "RAILS_LOG_TO_STDOUT", value = "true" },
        { name = "RAILS_SERVE_STATIC_FILES", value = "true" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = aws_cloudwatch_log_group.sugutan_api.name
          awslogs-region = data.aws_region.current.name
          awslogs-stream-prefix = "sugutan-api"
        }
      }
      portMappings = [
        {
          containerPort = 3000
          hostPort = 3000
          protocol = "tcp"
        }
      ]
    },
  }
}

resource "aws_ecs_task_definition" "sugutan_api" {
  container_definitions = jsonencode(
    values(local.container_definitions)
  )
  cpu = "256"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  family = "${var.stage}-sugutan-api"
  memory = "512"
  network_mode = "awsvpc"
  requires_compatibilities = [
    "FARGATE",
  ]
  task_role_arn = aws_iam_role.ecs_task.arn
  skip_destroy = true
}

# ======= ECS service =======
resource "aws_ecs_service" "sugutan_api" {
  cluster         = aws_ecs_cluster.sugutan_api.id
  desired_count   = 0
  enable_execute_command = true
  health_check_grace_period_seconds = 60
  launch_type = "FARGATE"
  name            = "sugutan-api"
  task_definition = aws_ecs_task_definition.sugutan_api.arn

  deployment_circuit_breaker {
    enable = true
    rollback = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.sugutan_api.arn
    container_name   = local.container_definitions.sugutan_api.name
    container_port   = 3000
  }

  network_configuration {
    security_groups = [
      aws_security_group.ecs_instance.id
    ]
    subnets = data.aws_subnets.public.ids
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }
}

# ======= RDS =======
# RDS用のサブネットグループ（必須）
resource "aws_db_subnet_group" "sugutan_api" {
  name       = "${var.stage}-sugutan-api-db-subnet"
  subnet_ids = data.aws_subnets.private.ids
}

# RDSインスタンス
resource "aws_db_instance" "sugutan_api" {
  identifier           = "${var.stage}-sugutan-api-db"
  engine               = "postgres"
  engine_version       = "17.6" # 最新の安定版を指定
  instance_class       = "db.t4g.micro" # 無料枠対象(t3.micro/t4g.micro)
  allocated_storage     = 20    # 無料枠内(最大20GB)
  storage_type         = "gp2"

  # DB接続情報
  db_name              = data.aws_ssm_parameter.sugutan_api_db_name.value
  username             = data.aws_ssm_parameter.sugutan_api_db_username.value
  password             = data.aws_ssm_parameter.sugutan_api_db_password.value

  db_subnet_group_name   = aws_db_subnet_group.sugutan_api.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible  = false # インターネットから遮断
  skip_final_snapshot  = true  # 削除時にバックアップを取らない（開発用）
  multi_az             = false # 無料枠のためfalse
}

# 作成後に決まるホスト名をSSMに書き込む
resource "aws_ssm_parameter" "sugutan_api_db_host" {
  name  = "/sugutan-api/${var.stage}/rds/db_host"
  type  = "String"
  value = aws_db_instance.sugutan_api.address
}

# ====== ACM ======
# ホストゾーンの情報を取得
data "aws_route53_zone" "sugutan_api" {
  name = "sugutan.site"
}

# ACM証明書のリクエスト
resource "aws_acm_certificate" "sugutan_api" {
  domain_name       = "api.sugutan.site"
  validation_method = "DNS"
  # ダウンタイムを生まないためにリソース更新時に新規作成→旧版削除の順番で行う設定
  lifecycle {
    create_before_destroy = true
  }
}

# DNS検証用レコードをRoute53に作成
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.sugutan_api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.sugutan_api.zone_id
}

# 検証が完了するまで待機するリソース
resource "aws_acm_certificate_validation" "sugutan_api" {
  certificate_arn         = aws_acm_certificate.sugutan_api.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


# ====== Route53 =======
resource "aws_route53_record" "sugutan_api_alb" {
  zone_id = data.aws_route53_zone.sugutan_api.zone_id
  name    = "api.sugutan.site"
  type    = "A"

  alias {
    name                   = aws_lb.sugutan_api.dns_name
    zone_id                = aws_lb.sugutan_api.zone_id
    evaluate_target_health = true
  }
}
