# ----------------------------------------------------------------------------------------------------------------------
# 🟢 NETWORK
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_vpc" "aws-vpc" {
  cidr_block           = var.aws-network-cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Name" = var.aws-network-name
  }
}

resource "aws_subnet" "aws-subnet1" {
  vpc_id     = aws_vpc.aws-vpc.id
  cidr_block = var.aws-subnet-cidr

  tags = {
    Name = "${aws_vpc.aws-vpc.id}-subnetwork"
  }
}

resource "aws_internet_gateway" "aws-vpc-igw" {
  vpc_id = aws_vpc.aws-vpc.id

  tags = {
    Name = var.aws-vpc-ig
  }
}


# ----------------------------------------------------------------------------------------------------------------------
# 🟢 FIREWALL RULES
# ----------------------------------------------------------------------------------------------------------------------

# PING
resource "aws_security_group" "aws-allow-icmp" {
  name        = "aws-allow-icmp"
  description = "Allow icmp access from anywhere"
  vpc_id      = aws_vpc.aws-vpc.id

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["${var.my_ip_address}/32"]
  }
}

# SSH
resource "aws_security_group" "aws-allow-ssh" {
  name        = "aws-allow-ssh"
  description = "Allow ssh access from anywhere"
  vpc_id      = aws_vpc.aws-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip_address}/32"]
  }
}

# Allow traffic from the VPN subnets.
resource "aws_security_group" "aws-allow-vpn" {
  name        = "aws-allow-vpn"
  description = "Allow all traffic from vpn resources"
  vpc_id      = aws_vpc.aws-vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.gcp-subnetwork-ip-cidr-range]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.gcp-subnetwork-ip-cidr-range]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.gcp-subnetwork-ip-cidr-range]
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.aws-vpc.id

  ingress {}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "aws-allow-gcp-vm" {
  name        = "aws-allow-gcp-vm"
  description = "Allow traffic from GCP VM only"
  vpc_id      = aws_vpc.aws-vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [ "${var.gcp-vm-address}/32" ]
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# 🟢 VPN CONNECTION
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_vpn_gateway" "aws-vpn-gw" {
  vpc_id = aws_vpc.aws-vpc.id
}

resource "aws_default_route_table" "aws-vpc" {
  default_route_table_id = aws_vpc.aws-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws-vpc-igw.id
  }
  propagating_vgws = [
    aws_vpn_gateway.aws-vpn-gw.id,
  ]
}

# ----------------------------------------------------------------------------------------------------------------------
# 🟢 VPN TUNNEL N°1
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_customer_gateway" "aws-cgw-1" {
  bgp_asn    = 65000
  ip_address = google_compute_ha_vpn_gateway.gcp-vpn-gw.vpn_interfaces[0].ip_address
  type       = "ipsec.1"
  tags = {
    "Name" = "aws-customer-gw"
  }
}

resource "aws_vpn_connection" "aws-vpn-connection1" {
  vpn_gateway_id      = aws_vpn_gateway.aws-vpn-gw.id
  customer_gateway_id = aws_customer_gateway.aws-cgw-1.id
  type                = "ipsec.1"
  static_routes_only  = false
  tags = {
    "Name" = "aws-vpn-connection1"
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# 🟢 VPN TUNNEL N°2
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_customer_gateway" "aws-cgw-2" {
  bgp_asn    = 65000
  ip_address = google_compute_ha_vpn_gateway.gcp-vpn-gw.vpn_interfaces[1].ip_address
  type       = "ipsec.1"
  tags = {
    "Name" = "aws-customer-gw"
  }
}

resource "aws_vpn_connection" "aws-vpn-connection2" {
  vpn_gateway_id      = aws_vpn_gateway.aws-vpn-gw.id
  customer_gateway_id = aws_customer_gateway.aws-cgw-2.id
  type                = "ipsec.1"
  static_routes_only  = false
  tags = {
    "Name" = "aws-vpn-connection2"
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# 🟢 ELASTIC COMPUTE CLOUD
# ----------------------------------------------------------------------------------------------------------------------


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.aws-disk-image]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_eip" "aws-ip" {
  # vpc = true

  instance                  = aws_instance.aws-vm.id
  associate_with_private_ip = var.aws-vm-address
}

resource "aws_instance" "aws-vm" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.aws-instance-type
  subnet_id     = aws_subnet.aws-subnet1.id

  associate_public_ip_address = false
  private_ip                  = var.aws-vm-address

  vpc_security_group_ids = [
    aws_security_group.aws-allow-icmp.id,
    aws_security_group.aws-allow-ssh.id,
    aws_security_group.aws-allow-vpn.id,
    aws-allow-gcp-vm.id
  ]

  tags = {
    Name = "aws-vm-${var.aws-region}"
  }
}