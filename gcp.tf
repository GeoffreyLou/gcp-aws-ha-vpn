# ---------------
# --- NETWORK ---
# ---------------

resource "google_compute_network" "main" {
  name                    = var.gcp-network-name
  project                 = var.gcp-project
  auto_create_subnetworks = "false"

}

resource "google_compute_subnetwork" "gcp-subnet1" {
  name          = "${google_compute_network.main.name}-subnet"
  project       = var.gcp-project
  ip_cidr_range = var.gcp-subnetwork-ip-cidr-range
  network       = google_compute_network.main.id
  region        = var.gcp-region
}


# ----------------------
# --- FIREWALL RULES ---
# ----------------------

# PING
resource "google_compute_firewall" "gcp-allow-icmp" {
  name    = "${google_compute_network.main.name}-gcp-allow-icmp"
  network = google_compute_network.main.name
  project = var.gcp-project

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    "${var.my_ip_address}/32"
  ]

  target_tags = ["allow-icmp"]
}

# SSH
resource "google_compute_firewall" "gcp-allow-ssh" {
  name    = "${google_compute_network.main.name}-gcp-allow-ssh"
  network = google_compute_network.main.name
  project = var.gcp-project

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [
    "${var.my_ip_address}/32"
  ]

  target_tags = ["allow-ssh"]
}

# Traffic from VPN subnets
resource "google_compute_firewall" "gcp-allow-vpn" {
  name    = "${google_compute_network.main.name}-gcp-allow-vpn"
  network = google_compute_network.main.name
  project = var.gcp-project

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    var.aws-subnet-cidr,
  ]
}

# TCP traffic from Internet
resource "google_compute_firewall" "gcp-allow-internet" {
  name          = "${google_compute_network.main.name}-gcp-allow-internet"
  network       = google_compute_network.main.name
  project       = var.gcp-project
  target_tags   = ["web"]
  source_ranges = [
    "0.0.0.0/0",
  ]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "https" {
  name          = "gcp-network-https"
  network       = google_compute_network.main.name
  project       = var.gcp-project
  direction     = "INGRESS"
  target_tags   = ["web"]
  source_ranges = [
    "0.0.0.0/0"
  ]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "gcp-allow-aws-vm" {
  name    = "${google_compute_network.main.name}-gcp-allow-aws-vm"
  network = google_compute_network.main.name
  project = var.gcp-project

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }


  source_ranges = [
    var.aws-vm-address 
  ]

  target_tags = ["allow-aws-vm"]
}


# ----------------------
# --- VPN CONNECTION ---
# ----------------------

resource "google_compute_ha_vpn_gateway" "gcp-vpn-gw" {
  name    = "gcp-vpn-gw-${var.gcp-region}"
  network = google_compute_network.main.id
  region  = var.gcp-region
  project = var.gcp-project
}

resource "google_compute_external_vpn_gateway" "external_gateway" {
  name            = "aws-gateway"
  redundancy_type = "FOUR_IPS_REDUNDANCY"
  description     = "Dual AWS VPN gateways"
  project         = var.gcp-project

  interface {
    id         = 0
    ip_address = aws_vpn_connection.aws-vpn-connection1.tunnel1_address
  }
  interface {
    id         = 1
    ip_address = aws_vpn_connection.aws-vpn-connection1.tunnel2_address
  }
  interface {
    id         = 2
    ip_address = aws_vpn_connection.aws-vpn-connection2.tunnel1_address
  }
  interface {
    id         = 3
    ip_address = aws_vpn_connection.aws-vpn-connection2.tunnel2_address
  }  
}


# ----------------------
# --- VPN TUNNEL N°1 ---
# ----------------------

resource "google_compute_vpn_tunnel" "gcp-tunnel1" {
  name                            = "gcp-tunnel1"
  peer_external_gateway           = google_compute_external_vpn_gateway.external_gateway.id
  peer_external_gateway_interface = 0
  shared_secret                   = aws_vpn_connection.aws-vpn-connection1.tunnel1_preshared_key
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-vpn-gw.self_link
  router                          = google_compute_router.gcp-router1.name
  vpn_gateway_interface           = 0
  project                         = var.gcp-project
  region                          = var.gcp-region  
}

resource "google_compute_router" "gcp-router1" {
  name    = "gcp-router1"
  region  = var.gcp-region
  network = google_compute_network.main.id
  project = var.gcp-project

  bgp {
    asn               = aws_customer_gateway.aws-cgw-1.bgp_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_router_peer" "gcp-router1-peer" {
  name            = "gcp-to-aws-bgp1"
  router          = google_compute_router.gcp-router1.name
  region          = google_compute_router.gcp-router1.region
  peer_ip_address = aws_vpn_connection.aws-vpn-connection1.tunnel1_vgw_inside_address
  peer_asn        = "64512"
  interface       = google_compute_router_interface.router_interface1.name
  project         = var.gcp-project
}

resource "google_compute_router_interface" "router_interface1" {
  name       = "gcp-to-aws-interface1"
  router     = google_compute_router.gcp-router1.name
  region     = google_compute_router.gcp-router1.region
  ip_range   = "${aws_vpn_connection.aws-vpn-connection1.tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.gcp-tunnel1.name
  project    = var.gcp-project
}


# ----------------------
# --- VPN TUNNEL N°2 ---
# ----------------------

resource "google_compute_vpn_tunnel" "gcp-tunnel2" {
  name                            = "gcp-tunnel2"
  peer_external_gateway           = google_compute_external_vpn_gateway.external_gateway.id
  peer_external_gateway_interface = 1
  shared_secret                   = aws_vpn_connection.aws-vpn-connection1.tunnel2_preshared_key
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-vpn-gw.self_link
  router                          = google_compute_router.gcp-router2.name
  vpn_gateway_interface           = 0
  project                         = var.gcp-project
  region                          = var.gcp-region  
}

resource "google_compute_router" "gcp-router2" {
  name    = "gcp-router2"
  region  = var.gcp-region
  network = google_compute_network.main.id
  project = var.gcp-project
  bgp {
    asn = aws_customer_gateway.aws-cgw-1.bgp_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_router_peer" "gcp-router2-peer" {
  name            = "gcp-to-aws-bgp2"
  router          = google_compute_router.gcp-router2.name
  region          = google_compute_router.gcp-router2.region
  peer_ip_address = aws_vpn_connection.aws-vpn-connection1.tunnel2_vgw_inside_address
  peer_asn        = "64512"
  interface       = google_compute_router_interface.router_interface2.name
  project         = var.gcp-project
}

resource "google_compute_router_interface" "router_interface2" {
  name       = "gcp-to-aws-interface2"
  router     = google_compute_router.gcp-router2.name
  region     = google_compute_router.gcp-router2.region
  ip_range   = "${aws_vpn_connection.aws-vpn-connection1.tunnel2_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.gcp-tunnel2.name
  project    = var.gcp-project
}


# ----------------------
# --- VPN TUNNEL N°3 ---
# ----------------------

resource "google_compute_vpn_tunnel" "gcp-tunnel3" {
  name                            = "gcp-tunnel3"
  peer_external_gateway           = google_compute_external_vpn_gateway.external_gateway.id
  peer_external_gateway_interface = 2
  shared_secret                   = aws_vpn_connection.aws-vpn-connection2.tunnel1_preshared_key
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-vpn-gw.self_link
  router                          = google_compute_router.gcp-router3.name
  vpn_gateway_interface           = 1
  project                         = var.gcp-project
  region                          = var.gcp-region  
}

resource "google_compute_router" "gcp-router3" {
  name    = "gcp-router3"
  region  = var.gcp-region
  network = google_compute_network.main.id
  project = var.gcp-project
  bgp {
    asn = aws_customer_gateway.aws-cgw-2.bgp_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_router_peer" "gcp-router3-peer" {
  name            = "gcp-to-aws-bgp3"
  router          = google_compute_router.gcp-router3.name
  region          = google_compute_router.gcp-router3.region
  peer_ip_address = aws_vpn_connection.aws-vpn-connection2.tunnel1_vgw_inside_address
  peer_asn        = "64512"
  interface       = google_compute_router_interface.router_interface3.name
  project         = var.gcp-project
}

resource "google_compute_router_interface" "router_interface3" {
  name       = "gcp-to-aws-interface3"
  router     = google_compute_router.gcp-router3.name
  region     = google_compute_router.gcp-router3.region
  ip_range   = "${aws_vpn_connection.aws-vpn-connection2.tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.gcp-tunnel3.name
  project    = var.gcp-project
}


# ----------------------
# --- VPN TUNNEL N°4 ---
# ----------------------

resource "google_compute_vpn_tunnel" "gcp-tunnel4" {
  name                            = "gcp-tunnel4"
  peer_external_gateway           = google_compute_external_vpn_gateway.external_gateway.id
  peer_external_gateway_interface = 3
  shared_secret                   = aws_vpn_connection.aws-vpn-connection2.tunnel2_preshared_key
  ike_version                     = 2
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-vpn-gw.self_link
  router                          = google_compute_router.gcp-router4.name
  vpn_gateway_interface           = 1
  project                         = var.gcp-project
  region                          = var.gcp-region  
}

resource "google_compute_router" "gcp-router4" {
  name    = "gcp-router4"
  region  = var.gcp-region
  network = google_compute_network.main.id
  project = var.gcp-project

  bgp {
    asn = aws_customer_gateway.aws-cgw-2.bgp_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_router_peer" "gcp-router4-peer" {
  name            = "gcp-to-aws-bgp4"
  router          = google_compute_router.gcp-router4.name
  region          = google_compute_router.gcp-router4.region
  peer_ip_address = aws_vpn_connection.aws-vpn-connection2.tunnel2_vgw_inside_address
  peer_asn        = "64512"
  interface       = google_compute_router_interface.router_interface4.name
  project         = var.gcp-project
}

resource "google_compute_router_interface" "router_interface4" {
  name       = "gcp-to-aws-interface4"
  router     = google_compute_router.gcp-router4.name
  region     = google_compute_router.gcp-router4.region
  ip_range   = "${aws_vpn_connection.aws-vpn-connection2.tunnel2_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.gcp-tunnel4.name
  project    = var.gcp-project
}


# ----------------------
# --- COMPUTE ENGINE ---
# ----------------------

resource "google_compute_address" "gcp-ip" {
  name    = "gcp-vm-ip-${var.gcp-region}"
  region  = var.gcp-region
  project = var.gcp-project
}

resource "google_compute_instance" "gcp-vm" {
  name         = "gcp-vm-${var.gcp-region}"
  machine_type = var.gcp-instance-type
  zone         = var.gcp-zone
  project      = var.gcp-project
  tags         =  ["allow-ssh", "allow-icmp", "web", "allow-aws-vm"]

  boot_disk {
    initialize_params {
      image = var.gcp-disk-image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.gcp-subnet1.id
    network_ip = var.gcp-vm-address

  }
}