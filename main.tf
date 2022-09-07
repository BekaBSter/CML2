terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

resource "yandex_iam_service_account" "sysadmin2" {
  name = "sysadmin2"
}

resource "yandex_resourcemanager_folder_iam_member" "sysadmin2" {
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sysadmin2.id}"
  folder_id = var.folder_id
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sysadmin2.id
  description        = "static access key for object storage"
}

resource "yandex_storage_bucket" "cml3" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "cml3"
}

resource "yandex_storage_object" "cml3" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "yandex_storage_bucket.cml3.bucket"
  key        = "cml3"
  source     = "cml240_rev2-disk1.vmdk"
  content_type = "gzipbase64"
}

resource "yandex_compute_image" "cml3" {
  name       = "cml3"
  os_type    = "LINUX"
  source_url = yandex_storage_object.cml3.url
  pooled     = "false"
  
  timeouts {
	create = "1h"
	delete = "30m"
  }
  
}

resource "yandex_compute_instance" "cml3" {

  name        = "cml3"
  platform_id = "standard-v3"

  resources {
    cores  = 4
    memory = 8
  }

  boot_disk {
    initialize_params {
      image_id = yandex_compute_image.cml3.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-for-cml.id
    nat       = true
  }

  metadata = {
    ssh-keys = windows:${file("id_rsa.pub")}
	serial_port_access = 1
  }
}

resource "yandex_vpc_network" "network-for-cml" {
  name = "network-for-cml"
}

resource "yandex_vpc_subnet" "subnet-for-cml" {
  name           = "subnet-for-cml"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-for-cml.id
  v4_cidr_blocks = ["192.168.0.0/16"]
}
