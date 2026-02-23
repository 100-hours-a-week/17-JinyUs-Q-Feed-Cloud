resource "aws_db_subnet_group" "main" {
  name       = "qfeed-prod-rds-subnetgroup"
  subnet_ids = [aws_subnet.private_data_a.id, aws_subnet.private_data_c.id]

  tags = merge(local.common_tags, { Name = "qfeed-prod-rds-subnetgroup" })
}

resource "aws_db_instance" "postgres" {
  identifier                  = "qfeed-prod-rds-postgres"
  engine                      = "postgres"
  engine_version              = "18.1"
  allow_major_version_upgrade = true
  apply_immediately           = false
  instance_class              = "db.t4g.small"
  availability_zone           = "ap-northeast-2a"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "qfeedproddb"
  username = var.db_username
  password = data.aws_ssm_parameter.db_password.value

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false
  storage_encrypted       = true
  backup_retention_period = 7
  multi_az                = false
  deletion_protection     = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "qfeed-prod-rds-final-snapshot"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, { Name = "qfeed-prod-rds-postgres" })
}
