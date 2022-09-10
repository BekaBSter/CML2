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
	  nat = "1"
    }

    metadata = {
	  foo = "bar"
      ssh-keys = "sysadmin:windows:${file("id_rsa.pub")}"
	  serial_port_access = "1"
    }
  }

  scale_policy {
    fixed_scale {
      size = var.size
    }
  }

  allocation_policy {
    zones = [var.zone]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion = 0
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
