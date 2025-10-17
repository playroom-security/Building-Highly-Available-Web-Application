// Security group for the ALB
resource "aws_security_group" "alb_sg" {
  name        = "playroom-alb-sg"
  description = "Allow HTTP from the world to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Security group for web instances
resource "aws_security_group" "web-sg" {
  name        = "playroom-web-sg"
  description = "Allow traffic from ALB and SSH from admin IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow HTTP from ALB"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.user_private_ip]
    description = "Allow SSH from admin IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Application Load Balancer in public subnets
resource "aws_lb" "app_alb" {
  name               = "playroom-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public-subnet-us-east-1a.id, aws_subnet.public-subnet-us-east-1b.id]
}

// Target group for the web instances (HTTP)
resource "aws_lb_target_group" "app_tg" {
  name     = "playroom-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

// Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

// Autoscaling group using the existing launch template
resource "aws_autoscaling_group" "web_asg" {
  name                      = "playroom-web-asg"
  max_size                  = 2
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = [aws_subnet.private-subnet-us-east-1a.id, aws_subnet.private-subnet-us-east-1b.id]
  launch_template {
    id      = aws_launch_template.web-application-tier-template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  tag {
    key                 = "Name"
    value               = "playroom-web-asg-instance"
    propagate_at_launch = true
  }
}
