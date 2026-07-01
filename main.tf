# 1. provider 설정
provider "aws"{
  region = var.region
}

data "aws_availability_zones" "available"{
  state = "available"
}


# 18. ALB 생성
resource "aws_lb" "prod"{
  name = "${var.name_prefix}-alb"
  internal = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]

  # ALB가 위치할 서브넷 지정
  subnets = [for s in aws_subnet.public : s.id]

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
  vpc_id = aws_vpc.this.id

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

# 21. 최신 리눅스 이미지 조회
data "aws_ami" "amazon_linux_2023"{
  most_recent = true
  owners = ["amazon"]

  filter{
    name = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 22. Lanuch template 생성
resource "aws_launch_template" "app"{
  name_prefix = "${var.name_prefix}-lt-"
  image_id = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3_micro"

  #네트워크 인터페이스 설정
  network_interfaces{
    security_groups = [aws_security_group.app.id]

    associate_public_ip_address = false
  }

  user_data = base64encdoe(
    <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from Terraform!"
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name_prefix}-app"
    }
  }
}

#23. Auto Scaling group 생성
resource "aws_autoscaling_group" "app"{
  name = "${var.name_prefix}-asg"
  # ASG가 EC2를 만들 때 어느 서브넷에 만들지 정함
  vpc_zone_identifier = [for s in aws_subnet.private : s.id]

  min_size = 2
  max_size = 4
  desired_capacity = 2

  launch_template{
    id = aws_launch_template.app.id
    version = "$Latest"
  }

  # ASG가 EC2를 새로 만들 때마다 자동으로 ALB 타겟 그룹 명단에 등록
  target_group_arns = [aws_lb_target_group.prod.arn]

  health_check_type = "ELB"
  health_check_grace_period = 300

  tag{
    key = "Name"
    value = "${var.name_prefix}-asg-instance"
    propagate_at_launch = true
  }
}

#24. DB 서브넷 그룹
resource "aws_db_subnet_group" "default"{
  name = "${var.name_prefix}-db-subnet-group"

  subnet_ids = [for s in aws_subnet.db : s.id]

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
  vpc_security_group_ids = [aws_security_group.db.id]

  skip_final_snapshot = true
  publicly_accessible = false

  tags = {
    Name = "${var.name_prefix}-mysql"
  }
}
module "vpc" {
  source = "./modules/vpc"
  name_prefix     = var.name_prefix
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  db_subnets      = var.db_subnets
}
module "s3" {
  source = "./modules/s3-buckets"
  name_prefix = var.name_prefix
}

module "cloudtrail" {
  source = "./modules/cloudtrail"
  name_prefix = var.name_prefix
  audit_bucket_policy_id = module.s3.audit_bucket_policy_id
  audit_bucket = module.s3.audit_bucket
  # 자식 모듈의 variable에 선언되어 있고 자식에 전달해줄 값
}