variable "tencentcloud_secret_id" {
  type      = string
  sensitive = true
}

variable "tencentcloud_secret_key" {
  type      = string
  sensitive = true
}

variable "do_name" {
  type        = string
  description = "Infrastructure project name"
  default     = "hexlet-devops-prod"
}

variable "do_token" {
  type      = string
  sensitive = true
}

variable "do_region" {
  type    = string
  default = "nyc3"
}

variable "do_ip_range" {
  type        = string
  description = "IP range for VPC"
  default     = "192.168.22.0/24"
}

variable "ssh_public_key_file" {
  type = string
}
variable "ssh_private_key_file" {
  type = string
}

variable "droplet_count" {
  type    = number
  default = 2
}

variable "droplet_image" {
  type        = string
  description = "OS to install on the servers"
  default     = "docker-20-04"
}

variable "droplet_size" {
  type    = string
  default = "s-1vcpu-1gb"
}

variable "domain_name" {
  type    = string
  default = "ant0n.xyz"
}

variable "subdomain_name" {
  type    = string
  default = "devops"
}

variable "database_count" {
  type = number
  default = 1
}

variable "database_size" {
  type = string
  default = "db-s-1vcpu-1gb"
}
