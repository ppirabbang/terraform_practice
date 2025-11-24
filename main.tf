# 1. 테라폼 설정 : aws 프로바이더를 사용하겠다고 선언
terraform{
  required_providers{
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
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
    security_groups = [aws_security_groups.web.id]
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

  tags = {
    Name = "my-3tier-app-server"
  }
}

output "web_public_ip"{
  value = aws_instance.web.public_ip
  description = "웹 서버의 공인 IP"
}

output "app_private_ip"{
  value = aws_instance.app_private_ip
  description = "앱 서버의 사설 IP"
}

# 17. Data Subnet A (기존 A존)
resource "aws_subnet" "data_a"{
  vpc_id = aws_vpc.main.id
  cidr_block = "10.10.3.0/24"
  availability_zone = "ap_northeast_2a"

  tags = {
    Name = "my-3tier-data-subnet-a"
  }
}

# 18. Data Subnet C (새로운 C존 - RDS 필수 조건!)
resource "aws_subnet" "data_c"{
  vpc_id = aws_vpc.main.id
  cidr_block = "10.10.4.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "my-3tier-data-subnet-c"
  }
}

# 19. DB 서브넷 그룹 (RDS는 이 그룹을 보고 어디에 들어갈지 정함)
resource "aws_db_subnet_group" "default"{
  name = "my-3ter-db-subnet-group"
  subnet_ids = [aws_subnet.data_a.id,aws_subnet.data_c.id]

  tags = {
    Name = "My DB subnet group"
  }
}

# 20. DB Security Group: 오직 App 서버만 3306 포트로 접근 가능
resource "aws_security_group" "db"{
  name = "my-3tier-db-sg"
  description = "Allow MySQL traafic from App Tier only"
  vpc_id = aws_vpc.main.id

  # Inbound: App SG 명찰을 단 녀석만 3306(MySQL) 통과
  ingress{
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # Outbound: 보통 DB는 밖으로 나갈 일이 없지만, 관례상 열어둠
  egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-3tier-db-sg"
  }
}

# 비밀번호를 입력받기 위한 빈 변수 선언
variable "db_password"{
  description = "RDS 데이터베이스 비밀번호를 입력하세요"
  type = string
  sensitive = true
}

# 21. RDS 인스턴스 (MySQL)
resource "aws_db_instance" "default" {
  allocated_storage    = 10              # 저장 용량 (10GB)
  db_name              = "mydb"          # DB 이름
  engine               = "mysql"         # 엔진 종류
  engine_version       = "8.0"           # 버전
  instance_class       = "db.t3.micro"   # 프리티어 무료 등급
  
  # 계정 정보
  username = "admin"
  password = var.db_password # 입력받은 변수를 사용!
  
  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.default.name # 아까 만든 그룹
  vpc_security_group_ids = [aws_security_group.db.id]     # 아까 만든 보안 그룹
  
  # 중요: 실습용 설정 (삭제 시 스냅샷 안 찍음)
  skip_final_snapshot    = true
  
  # 중요: 외부에서 절대 접속 불가 (True로 하면 퍼블릭 IP 생김 - 보안 위험)
  publicly_accessible    = false

  tags = {
    Name = "my-3tier-rds"
  }
}

# 22. RDS 접속 주소 출력
output "rds_endpoint" {
  value       = aws_db_instance.default.endpoint
  description = "RDS 접속 주소 (App 서버에서만 접속 가능)"
}