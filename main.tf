
terraform {
backend "s3" {

    bucket = "sashaa-tf-state-bucket"
    key    = "sashaa-tf-state-key"
    region = "us-west-2"
    }
  }



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


# Создание публичной подсети1
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true # для получения паблик айпи хостами сети
  tags = {
    Name = "Public-Subnet_1"
  }
}

# Создание публичной подсети2
resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-Subnet_2"
  }
}

# Создание route table для public subnets
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

# Присоединение public subnet1 к route table
resource "aws_route_table_association" "public_subnet_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Присоединение public subnet2 к route table
resource "aws_route_table_association" "public_subnet_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Создание приватной подсети1
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = aws_subnet.public_subnet_1.availability_zone
   tags = {
    Name = "Private-Subnet_1"
  }
}

# Создание приватной подсети2
resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = aws_subnet.public_subnet_2.availability_zone
   tags = {
    Name = "Private-Subnet_2"
  }
}

# создать 2 EIP для 2 NAT + сами NAT.всего нужно по 2 потому-что подключение будет идти с 2 подсетей в 2 подсети

# Создание elastic IP для NAT1
resource "aws_eip" "my_eip_1" {
  vpc = true
  tags = {
    Name = "my_elastic_IP_1"
  }
}

# Создание NAT gateway 1
resource "aws_nat_gateway" "my_nat_1" {
  allocation_id = aws_eip.my_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags = {
    Name = "my_NAT_gateway_1"
  }
 }

# Создание elastic IP для NAT2
resource "aws_eip" "my_eip_2" {
  vpc = true
  tags = {
    Name = "my_elastic_IP_2"
  }
}

# Создание NAT gateway 2
resource "aws_nat_gateway" "my_nat_2" {
  allocation_id = aws_eip.my_eip_2.id
  subnet_id     = aws_subnet.public_subnet_2.id
  tags = {
    Name = "my_NAT_gateway_2"
  }
 }


# Создание рут-таблиц для прайват подсетей и установка ассоциации "рут таблица-подсеть" 



# Создание route table для private subnet 1
resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_1.id
  }
  tags = {
    Name = "private-root-table_1"
  }
}

# Присоединение private subnet1 к private route table1
resource "aws_route_table_association" "private_subnet_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table_1.id
}

# Создание route table для private subnet 2
resource "aws_route_table" "private_route_table_2" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_2.id
  }
  tags = {
    Name = "private-root-table_2"
  }
}

# Присоединение private subnet2 к private route table2
resource "aws_route_table_association" "private_subnet_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table_2.id
}


# Создаем Application Load Balancer

resource "aws_lb" "web" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet_1.id,aws_subnet.public_subnet_2.id]
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
  name     = "my-target-group"
  depends_on = [aws_vpc.my_vpc]
  port     = 80 # порт, который открыт на бэк-энде для получение трафика от LB
  protocol = "HTTP"
  vpc_id = aws_vpc.my_vpc.id
  

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
  
  name = "lb-security_group"
  vpc_id = aws_vpc.my_vpc.id


ingress {
  from_port   = 22 # для ансибла и вообще для доступа
  to_port     = 22
  protocol    = "tcp"
  description = "HTTP"
  cidr_blocks = ["0.0.0.0/0"]
    }


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

# описание инстанса, который будет находиться в autosсaling group 
resource "aws_launch_configuration" "instance_template" {
  name_prefix   = "server_config"
  image_id      = "ami-0aa5fa88fa2ec19dc"
  instance_type = "t3.micro"
  security_groups = ["${aws_security_group.webserver_sg.id}"] 
  key_name = "sasha_kr_aws_ec2" # имя ssh ключа
 


  lifecycle {
        create_before_destroy = true # при изменении ресурса пересоздает его "с нуля"
     }
   
  ebs_block_device {
            device_name = "/dev/sdf"
            volume_type = "gp2"
            volume_size = 1
            encrypted   = true
        }
    
}

# создание сек'юрити - группы для бекенда

resource "aws_security_group" "webserver_sg" {
    name        = "backend_sg"
    vpc_id = aws_vpc.my_vpc.id
    #depends_on = [aws_security_group.wordpress_rds_sg]
    ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP"
      cidr_blocks = ["0.0.0.0/0"]
     }

    ingress {
      from_port   = 22 # для ансибла и вообще для доступа
      to_port     = 22
      protocol    = "tcp"
      description = "HTTP"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
    
    }

    # порты для RDS

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet_1.cidr_block,aws_subnet.private_subnet_2.cidr_block]
    #cidr_blocks = ["0.0.0.0/0"]
    #security_groups = [aws_security_group.wordpress_rds_sg.id] # ограничить правило группой безопасности RDS
  }


  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet_1.cidr_block,aws_subnet.private_subnet_2.cidr_block]
    #cidr_blocks = ["0.0.0.0/0"]
    #security_groups = [aws_security_group.wordpress_rds_sg.id]
  }

    tags = {
      Name = "backend_sg" 
      
    }
  }

  # Create Auto Scaling Group
resource "aws_autoscaling_group" "backend_scale_grp" {
  name               = "backend-scale-group"
  desired_capacity   = 1
  max_size           = 2
  min_size           = 1
  force_delete       = true #удаляет инстансы с удаление ASG
  depends_on         = [aws_lb.web]#сначала создать беленсер
  target_group_arns  =  ["${aws_lb_target_group.web.arn}"] #целевые группы, которые будут использоваться ALB
  health_check_type  = "EC2"
  launch_configuration = aws_launch_configuration.instance_template.name
  vpc_zone_identifier = ["${aws_subnet.private_subnet_1.id}","${aws_subnet.private_subnet_2.id}"]
  
 tag {
       key                 = "Name"
       value               = "back-scale-grp"
       propagate_at_launch = true
    }
}

# создание RDS 

# создание группы сетей, с которыми будет работать RDS 
resource "aws_db_subnet_group" "backend_db_subnet_group" {
  name        = "backend-db-subnet-group"
 
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id,
    
  ]
}

# создание инстанса базы данных

resource "aws_db_instance" "wordpress_db" {
  allocated_storage    = 2
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  name                 = "wordpress-db"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.mysql8.0"
  db_subnet_group_name = aws_db_subnet_group.backend_db_subnet_group.name

  vpc_security_group_ids = [aws_security_group.wordpress_rds_sg.id]

  tags = {
    Name = "wordpress-db"
  }
}

# сек группа для РДС

resource "aws_security_group" "wordpress_rds_sg" {
  name_prefix = "wordpress-rds-sg"
  vpc_id      = aws_vpc.wordpress_vpc.id
  #depends_on = [aws_security_group.webserver_sg]
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet_1.cidr_block,aws_subnet.private_subnet_2.cidr_block]
    
  }
  
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet_1.cidr_block,aws_subnet.private_subnet_2.cidr_block]
    
  }

  
  }

