resource "aws_secretsmanager_secret" "db_credentials" {
  name = "playroom/students-db-credentials"

  tags = {
    Name = "playroom-students-db-creds"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username,
    password = random_password.rds_master.result,
    db_name  = var.db_name,
    host     = aws_db_instance.students.address,
    port     = aws_db_instance.students.port
  })
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}
