env        = "dev"
aws_region = "ap-southeast-2"

vpc_cidr            = "10.1.0.0/16"
azs                 = ["ap-southeast-2a", "ap-southeast-2b"]
public_subnet_cidrs = ["10.1.0.0/24", "10.1.1.0/24"]
eks_subnet_cidr     = "10.1.10.0/24"
db_subnet_cidr      = "10.1.20.0/24"

db_secret_name         = "dev-db-credentials"
db_engine_version      = "16.8"
db_instance_class      = "db.t3.micro"
db_name                = "appdb"
db_allocated_storage   = 20
db_deletion_protection = false
db_multi_az            = false