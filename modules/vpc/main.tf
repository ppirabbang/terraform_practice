# 3. VPC 리소스 생성
resource "aws_vpc" "this"{
  cidr_block = var.vpc_cidr
  # DNS 호스트네임 활성화 (vpc 내 인스턴스에 퍼블릭 DNS 호스트네임을 자동으로 부여)
  enable_dns_hostnames = true
  # DNS 해석 활성화 (AWS에서 제공하는 DNS 서버 Route 53 Resolver 활성화)
  enable_dns_support = true 

  tags = {
    name = "${var.name_prefix}-vpc"
  }
}

# 4. public subnet 생성
resource "aws_subnet" "public"{
  for_each = var.public_subnets
  
  vpc_id = aws_vpc.this.id
  availability_zone = each.key
  # 변수의 왼쪽 값 (ap-northeast-2a)
  cidr_block = each.value
  # 변수의 오른쪽 값 (10.0.0.0/24)

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${each.key}"
  }
}

# 5. private subnet 생성
resource "aws_subnet" "private"{
  for_each = var.private_subnets
  
  vpc_id = aws_vpc.this.id
  availability_zone = each.key
  cidr_block = each.value

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-private-${each.key}"
  }
}

# 6. db subnet 생성
resource "aws_subnet" "db"{
  for_each = var.db_subnets
  
  vpc_id = aws_vpc.this.id
  availability_zone = each.key
  cidr_block = each.value

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-db-${each.key}"
  }
}

# 7. igw 생성
resource "aws_internet_gateway" "igw"{
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# 8. public route table 생성
resource "aws_route_table" "public"{
  vpc_id = aws_vpc.this.id

  #route 규칙 : 0.0.0.0/0 은 igw 로
  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name_prefix}-route-table-public"
  }
}

# 9. public subnet 에 route table 연결
resource "aws_route_table_association" "public"{
  # 만든 퍼블릭 서브넷 갯수 만큼 반복
  for_each = aws_subnet.public

  subnet_id = each.value.id
  #여기서 쓰는 value.id 는 subnet의 메타데이터 전부가 value 일거고 그 중 id를 사용하겠다는 것
  route_table_id = aws_route_table.public.id
}


# private app들이 쓸 nat gateway 선언, eip 반드시 필요
# 바로 igw로 보내는게 아님
# 10. NAT Gateway용 eip 생성
resource "aws_eip" "nat"{
  for_each = aws_subnet.public
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }
}

# 11. NAT Gateway 생성 (public subnet 중 하나에 배치)
resource "aws_nat_gateway" "this"{
  for_each = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id

  subnet_id = each.value.id

  tags = {
    Name = "${var.name_prefix}-nat-gw"
  }

  # IGW가 먼저 만들어져야 통신이 가능하므로 의존성 명시
  depends_on = [aws_internet_gateway.igw]
}

# 12. private route table 생성
# private에서 인터넷으로 트래픽 보낼거면 NAT 으로 보내라
# 그냥 지도 만드는 거니까 subnet에 관한 선언은 따로 없음
resource "aws_route_table" "private"{
  for_each = aws_nat_gateway.this
  # NAT Gateway 수 만큼 route table 생성
  vpc_id = aws_vpc.this.id

  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = each.value.id
  }

  tags = {
    Name = "${var.name_prefix}-rt-private"
  }
}

# 13. private subnet 에 route table 연결
resource "aws_route_table_association" "private"{
  for_each = aws_subnet.private

  subnet_id = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# 15. ALB Security Group (외부 -> ALB)
resource "aws_security_group" "alb"{
  name = "${var.name_prefix}-sg-alb"
  description = "Allow HTTP traffic from internet"
  vpc_id = aws_vpc.this.id

  # Inbound : 80번 허용
  ingress{
    from_port = 80
    to_port = 80
    protocol = "tcp"
    # tcp 허용하는게 http까지 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound
  egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg-alb"
  }
}

# 16. App Security Group
resource "aws_security_group" "app"{
  name = "${var.name_prefix}-sg-app"
  description = "Allow HTTP traffic from ALB only"
  vpc_id = aws_vpc.this.id

  # Inbound : 오직 ALB 보안 그룹에서 오는 트래픽만 허용
  ingress{
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 17. DB Security Group
resource "aws_security_group" "db"{
  name = "${var.name_prefix}-sg-db"
  description = "Allow MySQL traffic from App only"
  vpc_id = aws_vpc.this.id

  ingress{
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress{
    from_port = 0
    to_port = 0
    protocol = "-1"

    cidr_blocks = [aws_vpc.this.cidr_block]
    # 인터넷으로 트래픽이 나가는 대신 vpc 내부로만 나가도록
  }

  tags = {
    Name = "${var.name_prefix}-sg-db"
  }
}