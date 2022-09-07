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
  source_url = yandex_storage_object.cml3.id
  pooled     = "false"
  
  timeouts {
	create = "1h"
	delete = "30m"
  }
  
}

resource "yandex_iam_service_account" "ig-sa" {
  name        = "ig-sa"
  description = "service account to manage IG"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = var.folder_id
  role      = "editor"
  members   = [
    "serviceAccount:${yandex_iam_service_account.ig-sa.id}",
  ]
  depends_on = [
    yandex_iam_service_account.ig-sa,
  ]
}

resource "yandex_compute_instance_group" "ig-cml2" {
  name               = "fixed-ig-cml2"
  folder_id          = var.folder_id
  service_account_id = "${yandex_iam_service_account.ig-sa.id}"
  depends_on          = [yandex_resourcemanager_folder_iam_binding.editor]
  instance_template {
    platform_id = "standard-v3"
    resources {
      memory = 8
      cores  = 4
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = yandex_compute_image.cml3.id
      }
    }

    network_interface {
      network_id = "${yandex_vpc_network.network-for-cml.id}"
      subnet_ids = ["${yandex_vpc_subnet.subnet-for-cml.id}"]
    }

    metadata = {
      ssh-keys = "sysadmin:windows:${file("id_rsa.pub")}"
	  serial_port_access = 1
    }
  }

  scale_policy {
    fixed_scale {
      size = var.size
    }
  }

  allocation_policy {
    zones = ["var.zone"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion = 0
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "var.zone"
  network_id     = "${yandex_vpc_network.network-for-cml.id}"
  v4_cidr_blocks = ["192.168.0.0/24"]
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
