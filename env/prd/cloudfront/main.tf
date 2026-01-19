module "cloudfront" {
  source = "../../../usecases/cloudfront"
  stage = "prd"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
