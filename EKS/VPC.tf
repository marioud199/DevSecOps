provider  "aws" {
  region = "us-east-1"

}

resource "aws_vpc" "main_vpc" { 
  cidr_block = var.cidr_block
  enable_dns_hostnames = true
  tags = {
    name = "main_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  count = 2
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = var.public_subnet[count.index]
  availability_zone = var.availability_zone[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet"
    "kubernetes.io/cluster/dev" = "owned"
    "kubernetes.io/role/elb" = 1
  }
  
}

resource "aws_subnet" "private_subnet" {
  count = 2
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = var.private_subnet[count.index]
  availability_zone = var.availability_zone[count.index]
  tags = {
    Name = "private_subnet"
    "kubernetes.io/cluster/dev" = "owned"
    "kubernetes.io/role/internal-elb" = 1
  }
  map_public_ip_on_launch = false
}

resource "aws_internet_gateway" "main_igw" {
    vpc_id = aws_vpc.main_vpc.id
    tags = {
      Name = "main_igw"
    }
}
resource "aws_eip" "eip" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id = aws_subnet.public_subnet[0].id
  tags = {
    Name = "nat"
  }
 depends_on = [ aws_internet_gateway.main_igw ]
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  tags = {
    Name = "main_rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "main_rt2"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  count = 2
  subnet_id = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_rt_association" {
  count = 2
  subnet_id = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "main_sg" {
  name = "main_sg"
  vpc_id = aws_vpc.main_vpc.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  egress {
    from_port = 0 
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
