locals {
  common_tags = merge(
    {
      Environment = var.env
      Project     = "central-infra"
    },
    var.tags
  )
  db_secret_json = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)
  db_username    = local.db_secret_json.username
  db_password    = local.db_secret_json.password
  db_name        = coalesce(try(local.db_secret_json.dbname, null), var.db_name)
}

data "aws_secretsmanager_secret" "db" {
  name = var.db_secret_name
}

data "aws_secretsmanager_secret_version" "db" {
  secret_id = data.aws_secretsmanager_secret.db.id
}

resource "aws_db_subnet_group" "this" {
  name       = "central-${var.env}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "central-${var.env}-db-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = "central-${var.env}-db-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "central-${var.env}-db-sg"
  })
}

data "aws_rds_engine_version" "postgres" {
  engine = "postgres"
  preferred_versions = distinct(concat(
    [var.engine_version],
    ["16.8", "16.6", "16.4", "16.2", "15.12", "15.10", "15.8"]
  ))
}

resource "aws_db_instance" "this" {
  identifier = "central-${var.env}-postgres"

  engine            = "postgres"
  engine_version    = data.aws_rds_engine_version.postgres.version
  instance_class    = var.instance_class
  db_name           = local.db_name
  username          = local.db_username
  password          = local.db_password
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = false
  deletion_protection     = var.deletion_protection
  multi_az                = var.multi_az

  publicly_accessible = false

  tags = merge(local.common_tags, {
    Name = "central-${var.env}-postgres"
  })
}

resource "aws_secretsmanager_secret" "db" {
  name = "central-${var.env}-db-credentials"

  tags = merge(local.common_tags, {
    Name = "central-${var.env}-db-secret"
  })
}

resource "aws_secretsmanager_secret_version" "db_update" {
  secret_id = data.aws_secretsmanager_secret.db.id

  secret_string = jsonencode(
    merge(
      local.db_secret_json,
      {
        host   = aws_db_instance.this.address
        port   = aws_db_instance.this.port
        dbname = local.db_name
      }
    )
  )
}