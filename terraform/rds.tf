// RDS for students app
resource "aws_db_subnet_group" "students" {
  name       = "playroom-students-db-subnet-group"
  subnet_ids = [aws_subnet.public-subnet-us-east-1a.id, aws_subnet.public-subnet-us-east-1b.id]

  tags = {
    Name = "playroom-students-db-subnet-group"
  }
}

resource "random_password" "rds_master" {
  length  = 16
  special = true
}

resource "aws_security_group" "rds_sg" {
  name        = "playroom-rds-sg"
  description = "Allow MySQL from web tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web-sg.id]
    description     = "Allow MySQL from web SG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "students" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  identifier             = "playroom-students-db"
  db_name                = var.db_name
  username               = var.db_master_username
  password               = random_password.rds_master.result
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.students.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = "playroom-students-db"
  }
}

output "rds_endpoint" {
  value = aws_db_instance.students.address
}

output "rds_port" {
  value = aws_db_instance.students.port
}

output "rds_db_name" {
  value = aws_db_instance.students.db_name
}

output "rds_username" {
  value = aws_db_instance.students.username
}
