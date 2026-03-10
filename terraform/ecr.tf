resource "aws_ecr_repository" "status_page_ecr" {
  name                 = "alon-aviad-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}