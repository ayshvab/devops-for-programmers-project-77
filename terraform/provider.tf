terraform {
  
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "1.81.86"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.36.0"
    }
  }

  backend "cos" {
    region = "ap-guangzhou"
    bucket = "hexlet-bucket-1325533337"
    prefix = "terraform/state"
  }
}

provider "tencentcloud" {
  region     = "ap-guangzhou"
  secret_id  = var.tencentcloud_secret_id
  secret_key = var.tencentcloud_secret_key
}

provider "digitalocean" {
  token = var.do_token
}

# Terraform Backend
data "tencentcloud_user_info" "info" {}

resource "tencentcloud_cos_bucket" "private_sbucket" {
  bucket            = "hexlet-bucket-${data.tencentcloud_user_info.info.app_id}"
  versioning_enable = false
  lifecycle {
    prevent_destroy = true
  }
}
