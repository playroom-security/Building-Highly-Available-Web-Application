# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "Playroom-Lab-High-Availability-VPC"
  }
}

# Create public subnets in different availability zones
resource "aws_subnet" "public-subnet-us-east-1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr_block
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-us-east-1a"
  }
}
resource "aws_subnet" "public-subnet-us-east-1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr_block
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-us-east-1b"
  }
}

# Create private subnets
resource "aws_subnet" "private-subnet-us-east-1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr_block
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private-Subnet-us-east-1a"
  }
}

resource "aws_subnet" "private-subnet-us-east-1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr_block
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private-Subnet-us-east-1b"
  }
}


# Create an Intenet Gateway
resource "aws_internet_gateway" "playroom-lab-igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Playroom-Lab-IGW"
  }
}


# Create a route table
resource "aws_route_table" "playroom-igw-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    gateway_id = aws_internet_gateway.playroom-lab-igw.id
  }
}

resource "aws_route" "vpc_route" {
  route_table_id         = aws_route_table.playroom-igw-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.playroom-lab-igw.id

}

# Associate the route table with the public subnets
resource "aws_route_table_association" "public-subnet-us-east-1a-association" {
  subnet_id = aws_subnet.public-subnet-us-east-1a.id

  route_table_id = aws_route_table.playroom-igw-route-table.id
}

resource "aws_route_table_association" "public-subnet-us-east-1b-association" {
  subnet_id = aws_subnet.public-subnet-us-east-1b.id

  route_table_id = aws_route_table.playroom-igw-route-table.id
}

# Create an Elastic IP for the NAT Gateway
resource "aws_eip" "main-ngw-eip-us-east-1a" {
  domain = "vpc"
}

resource "aws_eip" "main-ngw-eip-us-east-1b" {
  domain = "vpc"
}


# Create NAT "<> " in each public subnet
resource "aws_nat_gateway" "playroom-lab-nat-gw-us-east-1a" {
  allocation_id = aws_eip.main-ngw-eip-us-east-1a.id
  subnet_id     = aws_subnet.public-subnet-us-east-1a.id

  tags = {
    Name = "Playroom-Lab-NAT-GW-us-east-1a"
  }
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.playroom-lab-igw]
}

resource "aws_nat_gateway" "playroom-lab-nat-gw-us-east-1b" {
  allocation_id = aws_eip.main-ngw-eip-us-east-1b.id
  subnet_id     = aws_subnet.public-subnet-us-east-1b.id

  tags = {
    Name = "Playroom-Lab-NAT-GW-us-east-1b"
  }
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.playroom-lab-igw]
}

## Create per-AZ private route tables and associate them with the corresponding NAT gateways
resource "aws_route_table" "private-nat-route-table-a" {
  vpc_id = aws_vpc.main.id

  route {
    gateway_id = aws_nat_gateway.playroom-lab-nat-gw-us-east-1a.id
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name = "playroom-private-nat-route-table-a"
  }
}

resource "aws_route_table" "private-nat-route-table-b" {
  vpc_id = aws_vpc.main.id

  route {
    gateway_id = aws_nat_gateway.playroom-lab-nat-gw-us-east-1b.id
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name = "playroom-private-nat-route-table-b"
  }
}

resource "aws_route_table_association" "private-subnet-us-east-1a-association" {
  subnet_id      = aws_subnet.private-subnet-us-east-1a.id
  route_table_id = aws_route_table.private-nat-route-table-a.id
}

resource "aws_route_table_association" "private-subnet-us-east-1b-association" {
  subnet_id      = aws_subnet.private-subnet-us-east-1b.id
  route_table_id = aws_route_table.private-nat-route-table-b.id
}

# Create a security group for public instances
resource "aws_security_group" "public-sg" {
  name        = "Playroom-Lab-Public-SG"
  description = "Allow inbound HTTP and SSH traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "Playroom-Lab-Public-SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-http-inbound" {
  security_group_id = aws_security_group.public-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  description       = "Allow inbound HTTP traffic"
}

resource "aws_vpc_security_group_ingress_rule" "allow-ssh-inbound" {
  security_group_id = aws_security_group.public-sg.id
  cidr_ipv4         = var.user_private_ip
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description       = "Allow inbound SSH traffic from my IP"

}


