output "vpc_id" {
  value = aws_vpc.networking.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.publicA.id,
    aws_subnet.publicB.id
  ]
}

output "private_subnet_ids" {
  value = [
    aws_subnet.privateA.id,
    aws_subnet.privateB.id
  ]
}
