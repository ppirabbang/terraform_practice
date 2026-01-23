variable "region"{
  description = "AWS 리전"
  type = string
  default = "ap-northeast-2"
}

variable "name_prefix"{
  description = "리소스 이름 접두사"
  type = string
  default = "my-project"
}

variable "vpc_cidr"{
  description = "VPC CIDR 블록"
  type = string
  default = "10.0.0.0/16"
}

variable "public_subnets"{
  description = "Public Subnet의 AZ 와 CIDR 매핑"
  type = map(string)
  default = {
    "ap-northeast-2a" = "10.0.0.0/24"
    "ap-northeast-2c" = "10.0.1.0/24"
  }
}

variable "private_subnets"{
  description = "Private Subnet 매핑"
  type = map(string)
  default = {
    "ap-northeast-2a" = "10.0.10.0/24"
    "ap-northeast-2c" = "10.0.11.0/24"
  }
}

variable "db_subnets" {
  description = "DB subnet 매핑"
  type = map(string)
  default = {
    "ap-northeast-2a" = "10.0.20.0/24"
    "ap-northeast-2c" = "10.0.21.0/24"
  }
}