resource "aws_ecr_repository" "sugutan_api" {
  name                 = "${var.stage}-sugutan-api"
  # image_tag_mutability = "IMMUTABLE" # 編集
}
# Railsで使用する環境変数
# DB関連
# resource "aws_ssm_parameter" "sugutan_api_db_host" {
#   name  = "/sugutan-api/${var.stage}/rds/db_host"
#   type  = "String"
#   value = "uninitialized"
#   lifecycle {
#     ignore_changes = [
#       value
#     ]
#   }
# }
resource "aws_ssm_parameter" "sugutan_api_db_name" {
  name  = "/sugutan-api/${var.stage}/rds/db_name"
  type  = "String"
  value = "uninitialized"
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
resource "aws_ssm_parameter" "sugutan_api_db_username" {
  name  = "/sugutan-api/${var.stage}/rds/db_username"
  type  = "String"
  value = "uninitialized"
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
resource "aws_ssm_parameter" "sugutan_api_db_password" {
  name  = "/sugutan-api/${var.stage}/rds/db_password"
  type  = "SecureString"
  value = "uninitialized"
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
resource "aws_ssm_parameter" "sugutan_api_rails_master_key" {
  name  = "/sugutan-api/${var.stage}/rds/rails_master_key"
  type  = "SecureString"
  value = "uninitialized"
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
resource "aws_ssm_parameter" "sugutan_api_smtp_username" {
  name  = "/sugutan-api/${var.stage}/smtp/smtp_username"
  type  = "SecureString"
  value = "uninitialized"
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
resource "aws_ssm_parameter" "sugutan_api_smtp_password" {
  name  = "/sugutan-api/${var.stage}/smtp/smtp_password"
  type  = "SecureString"
  value = "uninitialized"
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
resource "aws_ssm_parameter" "sugutan_api_gemini_api_key" {
  name  = "/sugutan-api/${var.stage}/gemini/gemini_api_key"
  type  = "SecureString"
  value = "uninitialized"
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
resource "aws_ssm_parameter" "sugutan_api_gmail_user_name" {
  name  = "/sugutan-api/${var.stage}/gmail/gmail_user_name"
  type  = "SecureString"
  value = "uninitialized"
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
resource "aws_ssm_parameter" "sugutan_api_gmail_password" {
  name  = "/sugutan-api/${var.stage}/gmail/gmail_password"
  type  = "SecureString"
  value = "uninitialized"
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
