# Repositories for the 7 app images, named as in k8s/overlays/eks/kustomization.yaml
# and scripts/push-images.sh: <registry>/dev/<name>
locals {
  app_images = [
    "api-gateway",
    "user-service",
    "product-service",
    "order-service",
    "notification-service",
    "storefront",
    "admin",
  ]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(local.app_images)

  name                 = "${var.environment}/${each.value}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # let `terraform destroy` remove repos that still hold images

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 20 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}
