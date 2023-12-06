variable "gcp_project_name" {
  type    = string
  default = "ecocompass-project"
}

variable "deployment_name" {
  type    = string
  default = "ec1"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "vpc_cidr" {
  type = string
}
