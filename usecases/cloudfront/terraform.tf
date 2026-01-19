terraform {
  required_version = ">=1.9.8"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">=5.72.1"
      configuration_aliases = [ aws.us_east_1 ]
    }
  }
}
