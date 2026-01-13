terraform {
  backend "s3" {
    bucket = "prd-tfstate-sugutan-project"
    key = "ecs_sugutan_api_infra/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
