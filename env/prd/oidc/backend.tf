terraform {
  backend "s3" {
    bucket = "prd-tfstate-sugutan-project"
    key = "oidc/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
