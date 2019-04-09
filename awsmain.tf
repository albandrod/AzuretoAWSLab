# Configure the AWS Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "192.168.0.0/19"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# AWS Route Table
resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.default.id}"
  propagating_vgws = ["aws_vpn_gateway.vpn_gw.id"]

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }

}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "192.168.1.0/24"
  map_public_ip_on_launch = true
}

# VPC GateWay
resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = "${aws_vpc.default.id}"

  tags = {
    Name = "AWS-GW"
  }
}

# AWS logic defined Azure VNET and GW
resource "aws_customer_gateway" "azure_gateway" {
  bgp_asn    = 65000
  ip_address = "${azurerm_public_ip.gwpip.ip_address}"
  type       = "ipsec.1"

  depends_on = ["azurerm_public_ip.gwpip"]
}

# AWS Connection to Azure
resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = "${aws_vpn_gateway.vpn_gw.id}"
  customer_gateway_id = "${aws_customer_gateway.azure_gateway.id}"
  type                = "ipsec.1"
  static_routes_only  = true

  depends_on = ["azurerm_virtual_network_gateway.azgw"]
}

# AWS Security Group Allow SSH
# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "awsvmsg" {
  name        = "AWSVM-SG"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#AWS Virtual Machine
resource "aws_instance" "awsvm" {
  connection {
    user = "${var.vmuser}"
    pass = "${var.vmpass}"

  }

  vpc_security_group_ids = ["aws_security_group.awsvmsg.id"]
  security_groups = ["${aws_security_group.awsvmsg.id}"]
  instance_type = "t2.micro"
  ami = "ami-0a313d6098716f372"
  subnet_id = "${aws_subnet.default.id}"

}

#AWS Route Propogation from S2S to RouteTables
resource "aws_vpn_gateway_route_propagation" "rtprop" {
  vpn_gateway_id = "${aws_vpn_gateway.vpn_gw.id}"
  route_table_id = "${aws_route_table.rt.id}"

  depends_on = ["azurerm_virtual_network_gateway_connection.azure2aws"]
}