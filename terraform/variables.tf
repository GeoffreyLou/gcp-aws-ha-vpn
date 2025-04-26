# ----------------------------------------------------------------------------------------------------------------------
# 🟢 Required parameters
# ----------------------------------------------------------------------------------------------------------------------

variable "my_ip_address" {
  description = "The IP address of the user to SSH into AWS and GCP instances"
  type        = string
}

variable "gcp-project" {
  description = "The project where the resources will be created"
  type        = string
}


# ----------------------------------------------------------------------------------------------------------------------
# 🟢 GCP 
# ----------------------------------------------------------------------------------------------------------------------

variable "gcp-network-name" {
  description = "The name of the network in GCP"
  type        = string
  default     = "gcp-to-aws-network"
}

variable "gcp-subnetwork-ip-cidr-range" {
  description = "The subnetwork for the GCP network"
  type        = string
  default     = "10.110.0.0/16"
}

variable "gcp-region" {
  description = "The region where the ressource will be deployed (Paris)"
  type        = string
  default     = "europe-west9"
}

variable "gcp-zone" {
  description = "The region where the ressource will be deployed"
  type        = string
  default     = "europe-west9-a"
}

variable "gcp-instance-type" {
  description = "The instance type for the Compute Engine"
  type        = string 
  default     = "e2-micro"
}

variable "gcp-disk-image" {
  description = "The disk image for the Compute Engine"
  type        = string 
  default     = "debian-cloud/debian-11"
}

variable "gcp-vm-address" {
  description = "The internal address for the Compute Engine"
  type        = string 
  default     = "10.110.0.100"
}

# ----------------------------------------------------------------------------------------------------------------------
# 🟢 AWS
# ----------------------------------------------------------------------------------------------------------------------

variable "aws-network-name" {
  description = "The name of the network in AWS"
  type        = string 
  default     = "aws-to-gcp-network"
}

variable "aws-region" {
  description = "The region where the resources will be Created (Paris)"
  type        = string
  default     = "eu-west-3"
}

variable "aws-network-cidr" {
  description = "The CIDR range for the whole AWS network"
  type        = string
  default     = "10.210.0.0/16"
}

variable "aws-subnet-cidr" {
  description = "The CIDR range for the subnet in the AWS network"
  type        = string
  default     = "10.210.0.0/24"
}

variable "aws-vpc-ig" {
  description = "The name of the AWS VPC Internet Gateway inside"
  type        = string 
  default     = "aws-vpc-internet-gateway"
}

variable "aws-vm-address" {
  description = "The internal address for the AWS EC2 instance"
  type        = string 
  default     = "10.210.0.100"
}

variable "aws-disk-image" {
  description = "The image disk for the AWS EC2 instance"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
}

variable "aws-instance-type" {
  description = "The instance type for the AWS EC2 instance"
  type        = string 
  default     = "t2.micro"
}