terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-a" # Зона доступности по умолчанию
}

data "yandex_compute_image" "my_image" {
  #family = "lemp"
  #family = "ubuntu-2004-lts" #ubuntu-2004-lts имеет несколько образов
  family = "ubuntu-2204-lts"
  #id="fd874d4jo8jbroqs6d7i" #Ubuntu 22.04 LTS
  #id можно проверить командой "yc compute image list --folder-id standard-images"
}

resource "yandex_compute_disk" "boot-disk" {
  name     = "boot-disk"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = 30
  image_id = data.yandex_compute_image.my_image.id
}

resource "yandex_compute_instance" "kube-master" {
  name = "kube-master"
  hostname = "kube-master"
  description = "Kubernetes master"

  resources {
    cores  = 4
    memory = 8
	core_fraction = 20 #Гарантированная доля vCPU - 20%
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "${file("ya_cloud_user_metadata.yml")}"
  }
  
#  provisioner "file" {
#    source      = "/home/alps/test_file"  # Local file path
#    destination = "/tmp/test_file"        # Path on the VM
#    
#    connection {
#      type     = "ssh"
#      host     = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
#      user     = "alps"
#      private_key = file("~/.ssh/YaCloudVMs")
#    }
#  }
  
  scheduling_policy {
    preemptible = true  #ВМ прерыраемая
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.kube-master.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.kube-master.network_interface.0.nat_ip_address
}