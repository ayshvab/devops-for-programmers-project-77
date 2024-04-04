terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "1.81.86"
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

data "tencentcloud_user_info" "info" {}

locals {
  app_id = data.tencentcloud_user_info.info.app_id
}

resource "tencentcloud_cos_bucket" "private_sbucket" {
  bucket            = "hexlet-bucket-${local.app_id}"
  versioning_enable = false
}
