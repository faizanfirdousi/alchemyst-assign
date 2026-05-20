variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "my_ip" {
  description = "Your public IP for SSH access (e.g., 203.0.113.1/32)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo URL to clone on each VM"
  type        = string
  default     = "https://github.com/faizanfirdousi/alchemyst-assign.git"
}

variable "dockerhub_user" {
  description = "Docker Hub username for pulling images"
  type        = string
  default     = "faizanfirdousi"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "alchemyst-inference"
}
