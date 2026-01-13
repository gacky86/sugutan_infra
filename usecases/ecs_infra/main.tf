resource "aws_ecr_repository" "sugutan_api" {
  name                 = "${var.stage}-sugutan-api"
  image_tag_mutability = "IMMUTABLE" # 編集
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
