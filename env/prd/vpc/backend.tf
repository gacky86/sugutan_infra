terraform {
  backend "s3" {
    bucket = "prd-tfstate-sugutan-project"
    key = "vpc/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
