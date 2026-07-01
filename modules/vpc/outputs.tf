output "vpc_id"{
  value = aws_vpc.this.id
}

output "vpc_cidr_block"{
  value = aws_vpc.this.cidr_block
}

output "security_group_alb"{
  value = aws_security_group.alb.id
}

output "security_group_app"{
  value = aws_security_group.app.id
}

output "public_subnet_ids"{
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids"{
  value = [for s in aws_subnet.private : s.id]
}

output "db_subnet_ids"{
  value = [for s in aws_subnet.db : s.id]
}

output "security_group_db"{
  value = aws_security_group.db.id
}