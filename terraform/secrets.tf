resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?" 
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "status-page-db-aa-credentials"
  description             = "Database credentials for Status Page"
  recovery_window_in_days = 0 
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_password.result
    engine   = "postgres"
    port     = 5432
  })
}

# =============================================================================
# Grafana Admin Password
# =============================================================================

resource "random_password" "grafana_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "grafana_credentials" {
  name                    = "status-page-grafana-credentials"
  description             = "Grafana admin credentials for the monitoring stack"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "grafana_credentials_version" {
  secret_id = aws_secretsmanager_secret.grafana_credentials.id
  secret_string = jsonencode({
    admin-user     = "admin"
    admin-password = random_password.grafana_password.result
  })
}