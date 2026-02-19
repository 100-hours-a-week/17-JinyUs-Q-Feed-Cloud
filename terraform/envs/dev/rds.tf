# -----------------------------------------------------------------------------
# DB Subnet Group (Private Subnet A + C, 2 AZ 필수)
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name = "qfeed-dev-rds-subnetgroup"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id,
  ]

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-rds-subnetgroup"
  })
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL — db.t4g.micro, Single-AZ
# -----------------------------------------------------------------------------

resource "aws_db_instance" "postgres" {
  identifier                  = "qfeed-dev-rds-postgres"
  engine                      = "postgres"
  engine_version              = "18.1"
  allow_major_version_upgrade = true
  apply_immediately           = true # dev 전용. prod에서는 false로 변경할 것
  instance_class              = "db.t4g.micro"
  availability_zone           = "ap-northeast-2a"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "qfeeddevdb"
  username = var.db_username
  password = data.aws_ssm_parameter.db_password.value

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false
  storage_encrypted       = true
  backup_retention_period = 1
  multi_az                = false
  skip_final_snapshot     = true

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-rds-postgres"
  })
}
