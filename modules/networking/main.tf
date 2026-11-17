resource "aws_vpc" "networking" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Environment = var.environment
    Name        = "${var.environment}-vpc"
  }
}

resource "aws_subnet" "publicA" {
  vpc_id                  = aws_vpc.networking.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true
  tags = {
    Environment = var.environment
    Name        = "${var.environment}-public-a"
  }
}


resource "aws_subnet" "publicB" {
  vpc_id                  = aws_vpc.networking.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true
  tags = {
    Environment = var.environment
    Name        = "${var.environment}-public-b"
  }
}


resource "aws_subnet" "privateA" {
  vpc_id                  = aws_vpc.networking.id
  cidr_block              = var.private_subnet_cidrs[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = false
  tags = {
    Environment = var.environment
    Name        = "${var.environment}-private-a"
  }
}


resource "aws_subnet" "privateB" {
  vpc_id                  = aws_vpc.networking.id
  cidr_block              = var.private_subnet_cidrs[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = false
  tags = {
    Environment = var.environment
    Name        = "${var.environment}-private-b"
  }
}

resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.networking.id

}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.networking.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }

}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.networking.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public.id
  }

}
resource "aws_route_table_association" "publicA" {
  subnet_id      = aws_subnet.publicA.id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "publicB" {
  subnet_id      = aws_subnet.publicB.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "privateA" {
  subnet_id      = aws_subnet.privateA.id
  route_table_id = aws_route_table.private.id
}


resource "aws_route_table_association" "privateB" {
  subnet_id      = aws_subnet.privateB.id
  route_table_id = aws_route_table.private.id
}
resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.publicA.id

  depends_on = [
    aws_internet_gateway.public
  ]

}
resource "aws_eip" "nat" {
  domain = "vpc"
  depends_on = [
    aws_internet_gateway.public
  ]
}
