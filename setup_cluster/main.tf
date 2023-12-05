provider "google" {
  project     = "ecocompass-project"
  region      = "europe-west1"
}

resource "google_compute_network" "ec1_vpc" {
  name                    = "ec1-vpc"
  project                 = "ecocompass-project"
  routing_mode            = "REGIONAL"
  mtu                     = 1460
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "ec1_subnet_main" {
  name          = "ec1-subnet-main"
  network       = google_compute_network.ec1_vpc.self_link
  ip_cidr_range = "10.10.0.0/24"
  stack_type    = "IPV4_ONLY"
  region        = "europe-west1"
  description   = "default network"
}

resource "google_compute_firewall" "ec1_fw_k8s_internal" {
  depends_on = [google_compute_network.ec1_vpc]
  name    = "ec1-fw-k8s-internal"
  network = "ec1-vpc"
  direction = "INGRESS"
  priority = 1000

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "ipip"
  }
  source_ranges = ["10.10.0.0/24"]
}

resource "google_compute_firewall" "ec1_fw_k8s_external" {
  depends_on = [google_compute_network.ec1_vpc]
  name    = "ec1-fw-k8s-external"
  network = "ec1-vpc"
  direction = "INGRESS"
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "ec1_k8s_controller" {
  name         = "ec1-k8s-controller"
  project      = "ecocompass-project"
  zone         = "europe-west1-b"
  machine_type = "e2-custom-medium-4096"
  boot_disk {
    initialize_params {
      size = "32"
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  can_ip_forward    = true
  network_interface {
    network = google_compute_network.ec1_vpc.self_link
    subnetwork  = google_compute_subnetwork.ec1_subnet_main.self_link
    access_config {}
  }

  metadata = {
    "startup-script" = file("startup-controller.sh")
  }
}

resource "google_compute_instance" "ec1_k8s_worker" {
  count        =  2
  name         = "ec1-k8s-worker-${count.index}"
  project      = "ecocompass-project"
  zone         = "europe-west1-b"
  machine_type = "e2-custom-medium-4096"
  boot_disk {
    initialize_params {
      size = "32"
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  can_ip_forward    = true
  network_interface {
    network = google_compute_network.ec1_vpc.self_link
    subnetwork  = google_compute_subnetwork.ec1_subnet_main.self_link
    access_config {}
  }

  metadata = {
    "startup-script" = file("startup-worker.sh")
  }
}