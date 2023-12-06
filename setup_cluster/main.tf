provider "google" {
  project = var.gcp_project_name
  region  = var.region
}

resource "google_compute_network" "dep_vpc" {
  name                    = "${var.deployment_name}-vpc"
  project                 = var.gcp_project_name
  routing_mode            = "REGIONAL"
  mtu                     = 1460
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "dep_subnet_main" {
  name          = "${var.deployment_name}-subnet-main"
  network       = google_compute_network.dep_vpc.self_link
  ip_cidr_range = var.vpc_cidr
  stack_type    = "IPV4_ONLY"
  region        = var.region
  description   = "default network"
}

resource "google_compute_firewall" "dep_fw_k8s_internal" {
  depends_on = [google_compute_network.dep_vpc]
  name       = "${var.deployment_name}-fw-k8s-internal"
  network    = "${var.deployment_name}-vpc"
  direction  = "INGRESS"
  priority   = 1000

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
  source_ranges = [var.vpc_cidr]
}

resource "google_compute_firewall" "dep_fw_k8s_external" {
  depends_on = [google_compute_network.dep_vpc]
  name       = "${var.deployment_name}-fw-k8s-external"
  network    = "${var.deployment_name}-vpc"
  direction  = "INGRESS"
  priority   = 1000

  allow {
    protocol = "tcp"
    ports    = ["22", "6443", "30000"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "dep_k8s_controller" {
  name         = "${var.deployment_name}-k8s-controller"
  project      = var.gcp_project_name
  zone         = var.zone
  machine_type = "e2-custom-medium-4096"
  boot_disk {
    initialize_params {
      size  = "32"
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  can_ip_forward = true
  network_interface {
    network    = google_compute_network.dep_vpc.self_link
    subnetwork = google_compute_subnetwork.dep_subnet_main.self_link
    access_config {}
  }

  metadata = {
    "startup-script" = file("startup-controller.sh")
  }
}

resource "google_compute_instance_template" "dep_k8s_worker-template" {
  name         = "${var.deployment_name}-k8s-worker-template"
  project      = var.gcp_project_name
  machine_type = "e2-custom-medium-4096"
  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    disk_size_gb = 32
  }
  can_ip_forward = true
  network_interface {
    network    = google_compute_network.dep_vpc.self_link
    subnetwork = google_compute_subnetwork.dep_subnet_main.self_link
    access_config {}
  }

  metadata = {
    "startup-script" = file("startup-worker.sh")
  }
}

resource "google_compute_instance_group_manager" "dep_k8s_worker-group" {
  name               = "${var.deployment_name}-k8s-worker-group"
  project            = var.gcp_project_name
  zone               = var.zone
  base_instance_name = "${var.deployment_name}-k8s-worker"
  version {
    instance_template = google_compute_instance_template.dep_k8s_worker-template.self_link
  }
  target_size = 2
  named_port {
    name = "http"
    port = 30000
  }
}

resource "google_compute_http_health_check" "dep_k8s_worker-health_check" {
  name               = "${var.deployment_name}-k8s-worker-health-check"
  project            = var.gcp_project_name
  port               = 30000
  check_interval_sec = 5
  healthy_threshold  = 2
}

resource "google_compute_backend_service" "dep_k8s_worker-backend_service" {
  name             = "${var.deployment_name}-k8s-worker-backend-service"
  project          = var.gcp_project_name
  health_checks    = [google_compute_http_health_check.dep_k8s_worker-health_check.id]
  port_name        = "http"
  protocol         = "HTTP"
  session_affinity = "NONE"
  timeout_sec      = 30
  log_config {
    enable = false
  }
  backend {
    max_utilization = 0.8
    balancing_mode  = "UTILIZATION"
    group           = google_compute_instance_group_manager.dep_k8s_worker-group.instance_group
  }
}

resource "google_compute_url_map" "dep_k8s_worker-url_map" {
  name            = "${var.deployment_name}-k8s-worker-url-map"
  project         = var.gcp_project_name
  default_service = google_compute_backend_service.dep_k8s_worker-backend_service.id
}

resource "google_compute_target_http_proxy" "dep_k8s_worker-target_http_proxy" {
  name    = "${var.deployment_name}-k8s-worker-target-http-proxy"
  project = var.gcp_project_name
  url_map = google_compute_url_map.dep_k8s_worker-url_map.self_link
}

resource "google_compute_global_forwarding_rule" "dep_k8s_worker-forwarding_rule" {
  name                  = "${var.deployment_name}-k8s-worker-forwarding-rule"
  project               = var.gcp_project_name
  target                = google_compute_target_http_proxy.dep_k8s_worker-target_http_proxy.self_link
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
  ip_version            = "IPV4"
}


output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.dep_k8s_worker-forwarding_rule.ip_address
}
