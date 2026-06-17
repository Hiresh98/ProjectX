locals {
  name = "${var.project}-${var.environment}"
}

# Container image registry. Always-free within the 500 MB private-repo limit, so
# this stack is cheap to keep up. force_delete lets `down` remove it with images.
resource "aws_ecr_repository" "app" {
  name                 = "${var.project}/app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}
