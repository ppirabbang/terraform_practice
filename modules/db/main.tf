#24. DB 서브넷 그룹
resource "aws_db_subnet_group" "default"{
  name = "${var.name_prefix}-db-subnet-group"

  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${var.name_prefix}-db-subnet-group"
  }
}

#25. RDS 생성
resource "aws_db_instance" "default" {
  identifier = "${var.name_prefix}-mysql"
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  db_name = "mydb"
  username = "admin"
  password = "password1234!"

  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [var.security_group_db]

  skip_final_snapshot = true
  publicly_accessible = false

  tags = {
    Name = "${var.name_prefix}-mysql"
  }
}