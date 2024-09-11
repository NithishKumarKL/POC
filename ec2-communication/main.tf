# This code is for communicating InstanceA from InstanceB

provider "aws" {
  region = "us-east-2"
}

# Define the VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Define the subnet
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  tags = {
    Name = "main-subnet"
  }
  map_public_ip_on_launch = true
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public.id
}

# Create a security group for Instance A
resource "aws_security_group" "instance_a_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "instance-a-sg"
  description = "Allow SSH from Instance B and inbound traffic"
  #depends_on = [ aws_security_group.instance_b_sg ]

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.instance_b_sg.id] # Allow SSH from Instance B's security group
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "InstanceASG"
  }
}

# Create a security group for Instance B
resource "aws_security_group" "instance_b_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "instance-b-sg"
  description = "Allow SSH and all outbound traffic"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow all inbound traffic (adjust as needed)
  }

  tags = {
    Name = "InstanceBSG"
  }
}

# Create Instance A
resource "aws_instance" "instance_a" {
  ami           = data.aws_ami.ami.id # Replace with your AMI ID
  instance_type = "t2.micro"
  key_name      = "my-key-pair" # Ensure you have this key pair created
  subnet_id     = aws_subnet.main.id
  associate_public_ip_address = true
  security_groups = [aws_security_group.instance_a_sg.id]

  tags = {
    Name = "InstanceA"
  }
}

# Create Instance B
resource "aws_instance" "instance_b" {
  ami           = data.aws_ami.ami.id # Replace with your AMI ID
  instance_type = "t2.micro"
  key_name      = "my-key-pair" # Ensure you have this key pair created
  subnet_id     = aws_subnet.main.id
  associate_public_ip_address = true
  security_groups = [aws_security_group.instance_b_sg.id]

  provisioner "file" {
    source      = "my-key-pair.pem" # The path to your key file
    destination = "/home/ec2-user/my-key-pair.pem" # The destination path on the instance

     connection {
      type        = "ssh"
      user        = "ec2-user" # Replace with the appropriate user for your AMI
      private_key = file("my-key-pair.pem") # Path to your private SSH key
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ec2-user/my-key-pair.pem", # Adjust permissions
      "echo 'Key has been transferred!'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user" # Replace with the appropriate user for your AMI
      private_key = file("my-key-pair.pem") # Path to your private SSH key
      host        = self.public_ip
    }
  }


  tags = {
    Name = "InstanceB"
  }
}

data "aws_ami" "ami" {
    most_recent = true
    owners = [ "amazon" ]
    filter {
      name= "name"
      values=["amzn2-ami-hvm*"]
    }

  
}
