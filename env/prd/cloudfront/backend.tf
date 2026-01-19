terraform {
  backend "s3" {
    bucket = "prd-tfstate-sugutan-project"
    key = "cloudfront/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
