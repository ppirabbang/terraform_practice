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
  description = "Public Subnet"
  type = map(string)
  default = {
    "ap-northeast-2a" = "10.0.0.0/24"
    "ap-northeast-2c" = "10.0.3.0/24"
  }
}

variable "private_subnets"{
  description = "Private Subnet 매핑"
  type = map(string)
  default = {
<<<<<<< Updated upstream
    "ap-northeast-2a" = "10.0.1.0/24"
    "ap-northeast-2c" = "10.0.4.0/24"
=======
    "ap-northeast-2a" = "10.0.2.0/24"
    "ap-northeast-2c" = "10.0.3.0/24"
>>>>>>> Stashed changes
  }
}

variable "db_subnets" {
  description = "DB subnet 매핑"
  type = map(string)
  default = {
<<<<<<< Updated upstream
    "ap-northeast-2a" = "10.0.2.0/24"
=======
    "ap-northeast-2a" = "10.0.4.0/24"
>>>>>>> Stashed changes
    "ap-northeast-2c" = "10.0.5.0/24"
  }
}