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

resource "digitalocean_database_cluster" "postgres_cluster" {
  name = "${var.do_name}-database-cluster"
  engine = "pg"
  version = "15"
  size = var.database_size
  region = var.do_region
  node_count = var.database_count
  private_network_uuid = digitalocean_vpc.web.id
}

resource "digitalocean_database_firewall" "postgres_cluster_firewall" {
  cluster_id = digitalocean_database_cluster.postgres_cluster.id
  rule {
    type = "tag"
    value = "${var.do_name}-webserver"
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

output "bastion_record" {
  value = digitalocean_record.bastion.fqdn
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

data "digitalocean_database_cluster" "postgres_cluster" {
  name = digitalocean_database_cluster.postgres_cluster.name
}

data "digitalocean_database_ca" "ca" {
  cluster_id = digitalocean_database_cluster.postgres_cluster.id
}

resource "local_file" "ansible_inventory" {
  content = templatefile("./templates/inventory.tmpl", {
    web_droplets = digitalocean_droplet.web.*
    bastion_droplet = digitalocean_droplet.bastion
  })
  filename = "../ansible/production/inventory.ini"
}

resource "local_file" "ssh_cfg" {
  content = templatefile("./templates/ssh_config.tmpl", {
    bastion_droplet = digitalocean_droplet.bastion
  })
  filename = "../ssh.cfg"
  file_permission = "0644"
}

resource "local_file" "tf_ansible_vars_file" {
  content = <<-DOC
    db_name: ${digitalocean_database_cluster.postgres_cluster.database}
    db_host: ${digitalocean_database_cluster.postgres_cluster.private_host}
    db_port: "${digitalocean_database_cluster.postgres_cluster.port}"
    db_user: ${digitalocean_database_cluster.postgres_cluster.user}
  DOC
  filename = "../ansible/production/group_vars/all/tf_ansible_vars_file.yml"
  file_permission = "0644"
}

# resource "local_sensitive_file" "db_prepared_ssl_cert" {
#   content = "${replace(data.digitalocean_database_ca.ca.certificate, "/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----|\n|[[:space:]]/", "")}"
#   filename = "../tmp/db_prepared_ssl_cert"
#   file_permission = "0644"
# }
