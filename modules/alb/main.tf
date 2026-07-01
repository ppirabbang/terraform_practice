# 18. ALB 생성
resource "aws_lb" "prod"{
  name = "${var.name_prefix}-alb"
  internal = false
  load_balancer_type = "application"

  security_groups = [var.security_group_alb]

  # ALB가 위치할 서브넷 지정
  subnets = [for s in var.public_subnets_ids : s.id]

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

# 19. Target Group 생성
# target group attachment 가 없으니 콘솔 작업처럼 빈 상태로 진행한 것이 맞음
resource "aws_lb_target_group" "prod"{
  name = "${var.name_prefix}-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = var.vpc_id

  health_check {
    path = "/"
    healthy_threshold = 3
    unhealthy_threshold = 3
    timeout = 5
    interval = 10
  }
}

# 20. Listener 생성
resource "aws_lb_listener" "http"{
  load_balancer_arn = aws_lb.prod.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.prod.arn
  }
}