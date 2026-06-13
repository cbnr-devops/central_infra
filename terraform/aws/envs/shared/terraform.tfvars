aws_region = "ap-southeast-2"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

azs = ["ap-southeast-2a", "ap-southeast-2b"]

ecr_repositories = [
  "solar-system",
  "starship-fleet"
]