output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public-subnet-us-east-1a.id, aws_subnet.public-subnet-us-east-1b.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private-subnet-us-east-1a.id, aws_subnet.private-subnet-us-east-1b.id]
}

output "public_security_group_id" {
  value = aws_security_group.public-sg.id
}

output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}

output "asg_name" {
  value = aws_autoscaling_group.web_asg.name
}
