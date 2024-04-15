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
    datadog = {
      source = "DataDog/datadog"
      version = "3.38.0"
    }
  }
 
  backend "cos" {
    region = "ap-guangzhou"
    bucket = "hexlet-bucket-05-1325533337"
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

provider "datadog" {
  api_key = var.datadog_api_key
  api_url = var.datadog_api_url
  app_key = var.datadog_app_key
}

# Terraform Backend
data "tencentcloud_user_info" "info" {}

output "tencentcloud_user_info" {
  value = data.tencentcloud_user_info.info.app_id
}

resource "tencentcloud_cos_bucket" "bucket" {
  bucket            = "hexlet-bucket-05-${data.tencentcloud_user_info.info.app_id}"
  versioning_enable = true
  # lifecycle {
  #   prevent_destroy = true
  # }
}
