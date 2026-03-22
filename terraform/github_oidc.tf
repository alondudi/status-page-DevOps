# Fetch the existing OIDC Provider for GitHub Actions
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Create the IAM Role that GitHub Actions will assume
resource "aws_iam_role" "github_actions" {
  name = "github-actions-devops-role"
  description = "Role assumed by GitHub Actions via OIDC"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
          StringLike = {
            # Scope to only branches/tags within your DevOps repository
            "token.actions.githubusercontent.com:sub" : "repo:alondudi/status-page-DevOps:*"
          }
        }
      }
    ]
  })
}

# Attach AdministratorAccess to the IAM Role
# Note: For production use cases, it's highly recommended to use a least-privilege policy instead of AdministratorAccess if possible.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Output the Role ARN so you can easily copy it into your GitHub Secrets as AWS_ROLE_ARN
output "github_actions_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}
