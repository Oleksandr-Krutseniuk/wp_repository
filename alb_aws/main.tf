
# remote state file in S3 bucket. bucket should exist before infrustructure deployment
terraform {
backend "s3" {

    bucket = "sashaa-tf-state-bucket" 
    key    = "sashaa-tf-state-key" # filename where tf-state is stored
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

# Internet gateway to make VPC accessible from inet
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "MyVPC-GW"
  }
}


# create public subnet1
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true # assigns public IP to the hosts upon creation
  tags = {
    Name = "Public-Subnet_1"
  }
}

# create public subnet2
resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-Subnet_2"
  }
}

# route table for public subnets.allows hosts from public subnets use gateway to communicate with hosts in internet
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

# Attach public subnet1 to route table (makes route table active within a subnet)
resource "aws_route_table_association" "public_subnet_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Attach public subnet2 to route table
resource "aws_route_table_association" "public_subnet_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create private subnet 1
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = aws_subnet.public_subnet_1.availability_zone
   tags = {
    Name = "Private-Subnet_1"
  }
}

# Create private subnet 2
resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = aws_subnet.public_subnet_2.availability_zone
   tags = {
    Name = "Private-Subnet_2"
  }
}

# create 2 EIP and 2 NAT.I need to establish connection from 2 private nets to 2 public - so I need 2 NATs. 

# elastic IP for NAT1.when using public NAT EIP attachment to a NAT is mandatory. 
resource "aws_eip" "my_eip_1" {
  vpc = true
  tags = {
    Name = "my_elastic_IP_1"
  }
}

# NAT gateway 1
resource "aws_nat_gateway" "my_nat_1" {
  allocation_id = aws_eip.my_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags = {
    Name = "my_NAT_gateway_1"
  }
 }

# elastic IP for NAT2
resource "aws_eip" "my_eip_2" {
  vpc = true
  tags = {
    Name = "my_elastic_IP_2"
  }
}

# NAT gateway 2
resource "aws_nat_gateway" "my_nat_2" {
  allocation_id = aws_eip.my_eip_2.id
  subnet_id     = aws_subnet.public_subnet_2.id
  tags = {
    Name = "my_NAT_gateway_2"
  }
 }

 
# route tables for private subnets.there will be 2 tables because each private subnet is attached to a separate public subnet.
# if I needed to attach private subnets to 1 public subnet - I would use 1 NAT and 1 root table instead


#  route table for private subnet 1
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

# attach private subnet1 to private route table1
resource "aws_route_table_association" "private_subnet_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table_1.id
}

#  route table for private subnet 2
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

# attach private subnet2 to private route table2
resource "aws_route_table_association" "private_subnet_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table_2.id
}


# Application Load Balancer

resource "aws_lb" "web" {
  name               = "my-load-balancer"
  internal           = false # makes LB publicly accessible
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet_1.id,aws_subnet.public_subnet_2.id] # subnets linked with load balancer
  security_groups    = ["${aws_security_group.lb.id}"] # points to a security group for load balancer
  
  tags = {
    Name = "my-load-balancer"
  }
}


# define a port and protocol, traffic from which load balancer would intercept 
resource "aws_lb_listener" "web" {
  load_balancer_arn = "${aws_lb.web.arn}" # points to LB the listener will be attached to
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.web.arn}" # target group,which would receive traffic from LB
    type             = "forward"
  }
}


# target group creation

resource "aws_lb_target_group" "web" {
  name     = "my-target-group"
  depends_on = [aws_vpc.my_vpc]
  port     = 80 # port used by backend to receive traffic from LB 
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

#  Security Group for ALB
resource "aws_security_group" "lb" {
  
  name = "lb-security_group"
  vpc_id = aws_vpc.my_vpc.id

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

# EC2 template for autosсaling group 
resource "aws_launch_configuration" "instance_template" {
  name_prefix   = "server_config"
  image_id      = "ami-0aa5fa88fa2ec19dc" # latest ubuntu
  instance_type = "t3.micro"
  security_groups = ["${aws_security_group.webserver_sg.id}"] # link to a security group for instances within autoscaling group
  key_name = "sasha_kr_aws_ec2" # ssh key, which is previously created and would be put into an EC2 upon creation
  
# PROVISIONER TESTS

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y apache2",
      "sudo systemctl start apache2",
      "sudo systemctl enable apache2"
    ]
  }



  lifecycle {
        create_before_destroy = true # before changes are applied a new resourse is created.
     }                               # only after new one is created the old one is deleted
   
  ebs_block_device {                 # device to store data in case EC2 is stopped or crashed
            device_name = "/dev/sdf"
            volume_type = "gp2"
            volume_size = 1
            encrypted   = true
        }
    
}

# security group for a backend servers

resource "aws_security_group" "webserver_sg" {
    name        = "backend_sg"
    vpc_id = aws_vpc.my_vpc.id

    ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP"
      cidr_blocks = ["0.0.0.0/0"]
     }
    
    ingress {
      from_port   = 22 
      to_port     = 22
      protocol    = "tcp"
      description = "HTTP"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1" # "all ports"
      cidr_blocks      = ["0.0.0.0/0"]
    
    }

    # ports for RDS

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
  force_delete       = true # when ASG is deleted related EC2s deleted as well
  depends_on         = [aws_lb.web] 
  target_group_arns  =  ["${aws_lb_target_group.web.arn}"] #target group attached to ALB
  health_check_type  = "EC2"
  launch_configuration = aws_launch_configuration.instance_template.name # ec2 configuration for instances withing autoscaling group
  vpc_zone_identifier = ["${aws_subnet.private_subnet_1.id}","${aws_subnet.private_subnet_2.id}"] #subnets where ec2 would be created
  
 tag {
       key                 = "Name"
       value               = "back-scale-grp"
       propagate_at_launch = true 
    }
}

# RDS creation 

# subnet group RDS is allowed to communicate with.subnet_ids field points to subnets where ec2 is set,which allows ->
resource "aws_db_subnet_group" "backend_db_subnet_group" {  # ---< "ec2-RDS" communication
  name        = "backend-db-subnet-group"
 
  subnet_ids = [
    aws_subnet.private_subnet_1.id, # private subnet1
    aws_subnet.private_subnet_2.id, # private subnet2
    
  ]
}

# database creation

resource "aws_db_instance" "wordpress_db" {
  allocated_storage    = 5
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = "******" #alphanumeric only is allowed
  username             = "******"
  password             = "******"
  parameter_group_name = "default.mysql8.0"
  db_subnet_group_name = aws_db_subnet_group.backend_db_subnet_group.name # subnets db communicates with

  vpc_security_group_ids = [aws_security_group.wordpress_rds_sg.id] # reference to db security group

  tags = {
    Name = "wordpress-db"
  }
}

# security group for RDS

resource "aws_security_group" "wordpress_rds_sg" {
  name_prefix = "wordpress-rds-sg"
  vpc_id      = aws_vpc.my_vpc.vpc_id

  # I used "cidr_blocks" field to allow traffic flow only within subnets where ec2 instances are located

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

