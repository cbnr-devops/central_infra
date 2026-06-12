locals {
  common_tags = merge(
    {
      Environment = var.env
      Project     = "central-infra"
    },
    var.tags
  )
}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name = each.value

  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(local.common_tags, {
    Name = "central-${var.env}-${each.value}"
  })
}

resource "aws_ecr_lifecycle_policy" "default" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 5 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}