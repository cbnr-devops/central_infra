terraform {
  backend "s3" {
    bucket = "sks-solar"   
    key    = "shared/terraform.tfstate" 
    region = "ap-southeast-2"               
    encrypt = true
    dynamodb_table = "terraform-state-lock"  
  }
}