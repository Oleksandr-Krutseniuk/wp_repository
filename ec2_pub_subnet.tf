# This code deploys 1 instance within a public subnet


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



# create public subnet1
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true # assigns public IP to the hosts upon creation
  availability_zone = "us-west-2a"
  tags = {
    Name = "Public-Subnet-1"
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




resource "aws_instance" "bastion" {
  ami           = "ami-0aa5fa88fa2ec19dc" # ID последнего Ubuntu AMI в регионе
  instance_type = "t2.micro"
  key_name      = "sasha_kr_aws_ec2" 
  associate_public_ip_address = true # Включаем автоматическое присвоение публичного IP-адреса
  vpc_security_group_ids = ["${aws_security_group.bastion_sg.id}"]
  subnet_id     = aws_subnet.public_subnet_1.id

  user_data = base64encode(file("${path.module}/python_ins.sh")) # immediate ansible installation

  tags = {
    Name = "bastion"
  }

}

resource "aws_security_group" "bastion_sg" { # если надо будет - добавлю 443
    name        = "bastion_sg"
    vpc_id = aws_vpc.my_vpc.id

    ingress {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"  
      cidr_blocks = ["0.0.0.0/0"]
     } 
     
    egress {
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"  
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"  
      cidr_blocks = ["0.0.0.0/0"]
     } 
     
    egress {
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"  
      cidr_blocks = ["0.0.0.0/0"]
    }
  
    ingress { 
      from_port   = 22 
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }  
    
    egress { 
      from_port   = 22 
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    } 
  }


