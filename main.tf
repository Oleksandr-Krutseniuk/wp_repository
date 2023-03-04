

# establish provider to use TF with AWS
provider "aws" {
  region = "us-west-2"
}

# create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my_vpc"
  }
}

# Создание Internet gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "MyVPC-GW"
  }
}

# Присоединение Internet gateway к VPC
resource "aws_internet_gateway_attachment" "my_igw_attachment" {
  vpc_id      = aws_vpc.my_vpc.id
  internet_gateway_id = aws_internet_gateway.my_igw.id
}



# Создание публичной подсети
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Public-Subnet"
  }
}



# Создание route table для public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
  tags = {
    Name = "Public-RT"
  }
}

# Присоединение public subnet к route table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Создание приватной подсети
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  availability_zone = "us-east-1a"
  tags = {
    Name = "Private-Subnet"
  }
}

# Создание route table для private subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat.id
  }
  tags = {
    Name = "private-RT"
  }
}

# Присоединение private subnet к route table
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# Создание elastic IP для NAT
resource "aws_eip" "my_eip" {
  vpc = true
}

# Создание NAT gateway
resource "aws_nat_gateway" "my_nat" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  depends_on = [aws_internet_gateway_attachment.my_igw_attachment]
}


# Настройка backend для хранения состояния
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "my-terraform-state"
    region = "us-west-2"
  }
}
