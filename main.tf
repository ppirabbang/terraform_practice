# 1. 테라폼 설정 : aws 프로바이더를 사용하겠다고 선언
terraform{
  required_providers{
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-3tier-tfstate-schoo-20241127" # 아까 만든 버킷 이름 (정확해야 함!)
    key            = "terraform.tfstate"          # S3 안에 저장될 파일 이름
    region         = "ap-northeast-2"
    dynamodb_table = "my-3tier-tf-locks"          # 아까 만든 테이블 이름
    encrypt        = true                         # 전송 중 암호화
  }
}


# 2. 프로바이더 설정 : 어느 리전에 만들 것인지 지정
provider "aws" {
  region = "ap-northeast-2"
}

# 3. 첫 번째 리소스 : VPC
resource "aws_vpc" "main"{
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "my-3tier-vpc"
  }
}

# 4. public subnet : 인터넷과 통신하는 서브넷
resource "aws_subnet" "web" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.10.1.0/24"

  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "my-3tier-web-subnet"
  }
}

# 5. 인터넷 게이트웨이 (IGW) : VPC의 대문
resource "aws_internet_gateway" "main"{
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "3-tier-igw"
  }
}

# 6. 라우트 테이블: 길 안내 지도 만들기
resource "aws_route_table" "public"{
  vpc_id = aws_vpc.main.id

  # "인터넷(0.0.0.0/0)으로 가는 트래픽은 현관문(igw)으로 보내라"는 규칙
  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "my-3tier-public-rt"
  }
}

# 7. 라우트 테이블 연결: Web 서브넷에게 이 지도를 쥐어주기
resource "aws_route_table_association" "web_public"{
  subnet_id = aws_subnet.web.id
  route_table_id = aws_route_table.public.id
}

# 8. App Subnet (Private): 외부 접근 차단
resource "aws_subnet" "app"{
  vpc_id = aws_vpc.main.id
  cidr_block = "10.10.2.0/24"

  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "my-3tier-app-subnet"
  }
}

# 9. NAT 게이트웨이용 공인 IP (고정 주소)
resource "aws_eip" "nat"{
  domain = "vpc"

  tags = {
    Name = "my-3tier-nat-ip"
  }
}

# 10. NAT 게이트웨이 (반드시 Public Subnet에 위치!)
resource "aws_nat_gateway" "main"{
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.web.id

  tags = {
    Name = "my-3tier-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

# 11. Private 라우트 테이블: "밖으로 나갈 땐 NAT를 타라"
resource "aws_route_table" "private"{
  vpc_id = aws_vpc.main.id

  route{
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "my-3tier-private-rt"
  }
}

# 12. Private 라우트 테이블 연결: App 서브넷에 이 지도를 적용
resource "aws_route_table_association" "app_private"{
  subnet_id = aws_subnet.app.id
  route_table_id = aws_route_table.private.id
}

# 13. Web Tier 보안 그룹: 인터넷 개방
resource "aws_security_group" "web"{
  name = "my-3tier-web-sg"
  description = "Allow HTTP traffic from internet"
  vpc_id = aws_vpc.main.id

  # Inbound (들어오는 규칙): 누구나 80포트 접속 가능
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound (나가는 규칙): 밖으로 나가는 건 모두 허용
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-3tier-web-sg"
  }
}

# 12. App Tier 보안 그룹: Web에서만 접근 허용 (보안의 핵심!)
resource "aws_security_group" "app"{
  name = "my-3tier-app-sg"
  description = "Allow traffic only from web tier"
  vpc_id = aws_vpc.main.id

  # Inbound: 오직 'Web 보안 그룹'을 통해서만 접근 가능
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    # 중요: IP가 아니라 '보안 그룹 ID'를 지정합니다.
    # 해당 sg에 속해 있는 데이터만 받겠다는 뜻, web subnet에서 온 것만 받겠다는 뜻
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id] 
    # 오직 Web 서버만 SSH 가능
  }

  # Outbound: 업데이트 등을 위해 밖으로(NAT로) 나가는 건 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-3tier-app-sg"
  }
}

# 13. 최신 Amazon Linux 2023 이미지(AMI) 정보 가져오기
data "aws_ami" "amazon_linux"{
  most_recent = true
  owners = ["amazon"]

  filter{
    name = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 14. Web Server (Public Subnet)
resource "aws_instance" "web"{
  ami = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  subnet_id = aws_subnet.web.id
  vpc_security_group_ids = [aws_security_group.web.id]

  key_name = "~~"
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  
  tags = {
    Name = "my-3tier-web-server"
  }
}

# 15. App Server (Private Subnet)
resource "aws_instance" "app"{
  ami = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  subnet_id = aws_subnet.app.id
  vpc_security_group_ids = [aws_security_group.app.id]

  key_name = "~~"

  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  tags = {
    Name = "my-3tier-app-server"
  }
}

output "web_public_ip"{
  value = aws_instance.web.public_ip
  value = aws_instance.web.public_ip
  description = "웹 서버의 공인 IP"
}

output "app_private_ip"{
  value = aws_instance.app.private_ip
  description = "앱 서버의 사설 IP"
}

# 23. 상태 파일 저장용 S3 버킷
resource "aws_s3_bucket" "tfstate"{
  bucket = "my-3tier-tfstate-schoo-20241127"
  tags = {
    Name = "Terraform State Bucket"
  }
}

# 24. S3 버킷 버전 관리 (실수로 지워도 복구 가능하게)
resource "aws_s3_bucket_versioning" "tfstate"{
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration{
    status = "Enabled"
  }
}

# 25. S3 버킷 암호화 (파일 내용을 암호화해서 저장) -> 보안 필수!
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate"{
  bucket = aws_s3_bucket.tfstate.id

  rule{
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 26. 잠금 장치용 DynamoDB 테이블
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "my-3tier-tf-locks"
  billing_mode = "PAY_PER_REQUEST" # 쓴 만큼만 비용 지불 (거의 공짜)
  hash_key     = "LockID"          # 필수: 테라폼은 이 키를 사용해 잠금을 겁니다.

  attribute {
    name = "LockID"
    type = "S" # String
  }
}

# 27. IAM Role 생성: "EC2가 사용할 수 있는 역할"
resource "aws_iam_role" "ssm_role"{
  name = "my-3tier-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 28. 정책 연결: AWS가 관리하는 'SSM 필수 권한'을 역할에 붙임
resource "aws_iam_role_policy_attachment" "ssm_policy"{
  role = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:picliy/AmazonSSMManagedInstanceCore"
}

# 29. 인스턴스 프로파일: 역할을 EC2에 끼울 수 있게 포장
resource "aws_iam_instance_profile" "ssm_profile"{
  name = "my-3tier-ssm-profile"
  role = aws_iam_role.ssm_role.name
}