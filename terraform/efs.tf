// EFS file system and mount targets for web servers
resource "aws_efs_file_system" "app_efs" {
  creation_token = "playroom-app-efs"
  tags = {
    Name = "playroom-app-efs"
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "playroom-efs-sg"
  description = "Allow NFS from web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.web-sg.id]
    description     = "Allow NFS from web servers"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_mount_target" "mt_a" {
  file_system_id  = aws_efs_file_system.app_efs.id
  subnet_id       = aws_subnet.private-subnet-us-east-1a.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "mt_b" {
  file_system_id  = aws_efs_file_system.app_efs.id
  subnet_id       = aws_subnet.private-subnet-us-east-1b.id
  security_groups = [aws_security_group.efs_sg.id]
}
