output "vpc_id"{
  value = aws_vpc.this.id
}

output "igw_id"{
  value = aws_internet_gateway.igw.id
}

output "route_table_public_id"{
  value = aws_route_table.public.id
}

output "nat_gateway_id"{
  value = aws_nat_gateway.this.id
}

output "route_table_private_id"{
  value = aws_route_table.private.id
}

output "security_group_alb"{
  value = aws_security_group.alb.id
}

output "security_group_app"{
  value = aws_security_group.app.id
}