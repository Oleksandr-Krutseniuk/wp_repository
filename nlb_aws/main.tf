

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
  availability_zone = aws_subnet.public_subnet.availability_zone # В этой зоне будет бекенд NLB и он должен находиться в одной с NLB зоне 
  tags = {
    Name = "Private-Subnet"
  }
  depends_on = [aws_subnet.public_subnet]
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
  depends_on = [aws_subnet.private_subnet]
}

# Присоединение private subnet к route table
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id

  depends_on = [aws_subnet.private_subnet]
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


# создаю ACL правило для Load Balancer, поскольку я исполюзую тип "network",
# который не поддерживает security groups

resource "aws_network_acl" "nlb_acl" {
  vpc_id = aws_vpc.my_vpc.id
  subnet_ids      = [aws_subnet.public_subnet.id]
}

# для вхощего трафика

resource "aws_network_acl_rule" "allow_http_ingress" {
  network_acl_id = aws_network_acl.nlb_acl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = false
 # subnet_id      = aws_subnet.public_subnet.id
 # subnet_ids = [
 #   aws_subnet.public_subnet.id
 #   ]
}

# для исходящего трафика

resource "aws_network_acl_rule" "allow_http_egress" {
  network_acl_id = aws_network_acl.nlb_acl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = true
 # subnet_id      = aws_subnet.public_subnet.id
 # subnet_ids = [
 #   aws_subnet.public_subnet.id
 #   ]
}

# ACL для частной сети

resource "aws_network_acl" "backend_acl" {
  vpc_id = aws_vpc.my_vpc.id
  subnet_ids      = [aws_subnet.private_subnet.id]
}

# для вхощего трафика

resource "aws_network_acl_rule" "allow_http_ingress_backend" {
  network_acl_id = aws_network_acl.backend_acl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = false
 # subnet_id      = aws_subnet.public_subnet.id
 # subnet_ids = [
 #   aws_subnet.public_subnet.id
 #   ]
}

resource "aws_network_acl_rule" "allow_http_egress_backend" {
  network_acl_id = aws_network_acl.backend_acl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = true
 # subnet_id      = aws_subnet.public_subnet.id
 # subnet_ids = [
 #   aws_subnet.public_subnet.id
 #   ]
}


# Создаем Network Load Balancer

resource "aws_lb" "web" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.private_subnet.id]
  
  
  subnet_mapping { # размещает беленсер в публичной подсети
    subnet_id = aws_subnet.public_subnet.id
    }

  tags = {
    Name = "my-load-balancer"
  }
}

# эта штука определяет порт, который слушает лоуд беленсер

resource "aws_lb_listener" "web" {
  load_balancer_arn = "${aws_lb.web.arn}" # указать ЛБ 
  port              = 80
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.web.arn}" # указывает таргет-группу, которой будет направлен трафик с ЛБ
    type             = "forward"
  }
}


# target group для лоуд беленсера, в которую будут входить машины для балансировки

resource "aws_lb_target_group" "web" {
  name     = "my-target-group"
  port     = 80 # порт, который открыт на бэк-энде для получение трафика от LB
  protocol = "TCP"
  
  vpc_id = aws_vpc.my_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 11
    #path                = "/"
    port                = 80
    protocol            = "TCP"
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
    
   }

  tags = {
    Name = "my_lb_target_group"
  }
}


# тут будет указано, какой ЕС2 будет входить в target group, связанную с лоад беленсером
resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = "${aws_lb_target_group.web.arn}"
  target_id        = aws_instance.ec2_instance.private_ip
  port             = 80
}



# создание EC2

resource "aws_instance" "ec2_instance" {
  ami           = "ami-0aa5fa88fa2ec19dc" # latest Ubuntu 20.04 LTS HVM EBS
  instance_type = "t3.micro"
  #availability_zone = "us-west-2b"
  subnet_id     = aws_subnet.private_subnet.id
  #availability_zone = aws_subnet.private_subnet.availability_zone # EC2 в данном случае должен быть в одной зоне с NLB
  tags = {
    Name = "My-EC2 Instance"
  }

  # Security Group allowing HTTP traffic from NLB
  security_groups = [aws_security_group.allow_http_for_ec2.id]
  depends_on = [
    aws_lb.web,
    aws_lb_target_group.web
    ]
}

# Security Group for EC2 allowing HTTP traffic from NLB
resource "aws_security_group" "allow_http_for_ec2" {
  name_prefix = "allow-http"

  /* 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "HTTP"
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }
*/
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
    description = "Allow inbound HTTP traffic"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }

  vpc_id = aws_vpc.my_vpc.id
}