resource "digitalocean_vpc" "web" {
  name     = "${var.do_name}-vpc"
  region   = var.do_region
  ip_range = var.do_ip_range
}

resource "digitalocean_ssh_key" "main" {
  name       = "${var.do_name}-key"
  public_key = file(var.ssh_public_key_file)
}

resource "digitalocean_droplet" "web" {
  count    = var.droplet_count
  image    = var.droplet_image
  name     = "web-${var.do_name}-${var.do_region}-${count.index + 1}"
  region   = var.do_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.main.id]
  vpc_uuid = digitalocean_vpc.web.id
  tags     = ["${var.do_name}-webserver"]

  connection {
    host        = self.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = file(var.ssh_private_key_file)
    timeout     = "2m"
  }

  # TODO Try provisioning with Ansible
  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      "sudo apt update",
      "sudo apt install -y nginx",
      "ufw allow 80/tcp"
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_domain" "default" {
  name = var.domain_name
}

resource "digitalocean_record" "subdomain-A" {
  domain = digitalocean_domain.default.id
  type   = "A"
  name   = var.subdomain_name
  value  = digitalocean_loadbalancer.public.ip
  ttl    = 30
}

resource "digitalocean_record" "CNAME-www" {
  depends_on = [digitalocean_domain.default]
  domain     = digitalocean_domain.default.id
  type       = "CNAME"
  name       = "www"
  value      = "@"
}

resource "digitalocean_certificate" "cert" {
  name    = "lecert01"
  type    = "lets_encrypt"
  domains = ["${var.subdomain_name}.${digitalocean_domain.default.name}", digitalocean_domain.default.name]
  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_loadbalancer" "public" {
  name                   = "${var.do_name}-loadbalancer"
  region                 = var.do_region
  droplet_ids            = digitalocean_droplet.web.*.id
  vpc_uuid               = digitalocean_vpc.web.id
  redirect_http_to_https = true

  forwarding_rule {
    entry_port     = 443
    entry_protocol = "https"

    target_port     = 80
    target_protocol = "http"

    certificate_name = digitalocean_certificate.cert.name
  }

  healthcheck {
    port     = 22
    protocol = "tcp"
  }
}

resource "digitalocean_firewall" "web" {
  name        = "${var.do_name}-only-vpc-traffic"
  droplet_ids = digitalocean_droplet.web.*.id
  inbound_rule {
    protocol         = "tcp"
    port_range       = "1-65535"
    source_addresses = [digitalocean_vpc.web.ip_range]
  }
  inbound_rule {
    protocol         = "udp"
    port_range       = "1-65535"
    source_addresses = [digitalocean_vpc.web.ip_range]
  }
  inbound_rule {
    protocol         = "icmp"
    source_addresses = [digitalocean_vpc.web.ip_range]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = [digitalocean_vpc.web.ip_range]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = [digitalocean_vpc.web.ip_range]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = [digitalocean_vpc.web.ip_range]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "80"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "443"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_droplet" "bastion" {
  image    = var.droplet_image
  name     = "bastion-${var.do_name}-${var.do_region}"
  region   = var.do_region
  size     = "s-1vcpu-1gb"
  ssh_keys = [digitalocean_ssh_key.main.id]
  vpc_uuid = digitalocean_vpc.web.id
  tags     = ["${var.do_name}-webserver"]
  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_record" "bastion" {
  domain = digitalocean_domain.default.id
  type   = "A"
  name   = "bastion-${var.do_name}-${var.do_region}"
  value  = digitalocean_droplet.bastion.ipv4_address
  ttl    = 300
}

resource "digitalocean_firewall" "bastion" {
  name        = "${var.do_name}-only-ssh-bastion"
  droplet_ids = [digitalocean_droplet.bastion.id]
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "22"
    destination_addresses = [digitalocean_vpc.web.ip_range]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = [digitalocean_vpc.web.ip_range]
  }
}

