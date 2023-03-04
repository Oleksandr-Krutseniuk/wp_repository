

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
#resource "aws_internet_gateway_attachment" "my_igw_attachment" {
  #vpc_id      = aws_vpc.my_vpc.id
  #internet_gateway_id = aws_internet_gateway.my_igw.id
#}



# Создание публичной подсети
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  #availability_zone = "us-east-1a"
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
  cidr_block = "10.0.2.0/24"
  #availability_zone = "us-east-1a"
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
  tags = {
    Name = "my_elastic_IP"
  }
}

# Создание NAT gateway
resource "aws_nat_gateway" "my_nat" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "my_NAT_gateway"
  }
 }






# Создаем Application Load Balancer

resource "aws_lb" "web" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnet.id
  security_groups    = ["${aws_security_group.lb.id}"] # указывает security group, в которую входит LB
  
  tags = {
    Name = "my-load-balancer"
  }
}

# эта штука определяет порт, который слушает лоуд беленсер

resource "aws_lb_listener" "web" {
  load_balancer_arn = "${aws_lb.web.arn}" # указать ЛБ 
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.web.arn}" # указывает таргет-группу, которой будет направлен трафик с ЛБ
    type             = "forward"
  }
}


#target group для лоуд беленсера, в которую будут входить машины для балансировки

resource "aws_lb_target_group" "web" {
  name     = "my_target_group"
  port     = 80 # порт, который открыт на бэк-энде для получение трафика от LB
  protocol = "HTTP"
  
  vpc_id = aws_vpc.my_vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    timeout             = 20
    healthy_threshold   = 2
    unhealthy_threshold = 2
   }

  tags = {
    Name = "my_lb_target_group"
  }
}

# Создаем Security Group для ALB
resource "aws_security_group" "lb" {
  # name_prefix = "example-lb-sg"

   ingress {
   from_port = 80
   to_port = 80
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
   }

   egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

   tags = {
    Name = "lb-security_group"
  }
 }

/*

# тут будет указано, какой ЕС2 будет входить в target group, связанную с лоад беленсером
resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = "${aws_lb_target_group.web.arn}"
  target_id        = "${aws_instance.web.id}"
  port             = 80
}

*/

