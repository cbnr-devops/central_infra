terraform {
  backend "s3" {
    bucket         = "central-infra-tf-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "central-infra-tf-lock"
    encrypt        = true
  }
}
