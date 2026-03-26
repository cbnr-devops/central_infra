terraform {
  backend "s3" {
    bucket         = "central-infra-tf-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
  }
}
