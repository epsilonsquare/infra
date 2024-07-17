terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source = "registry.terraform.io/hashicorp/google"
      version = "5.7.0"
    }

    wireguard = {
      source = "registry.terraform.io/OJFord/wireguard"
      version = "0.2.2"
    }

    kustomization = {
      source = "registry.terraform.io/kbst/kustomization"
      version = "0.9.5"
    }

    kubernetes = {
      source = "registry.terraform.io/hashicorp/kubernetes"
      version = "2.24.0"
    }

    github = {
      source = "registry.terraform.io/integrations/github"
      version = "5.42.0"
    }

    random = {
      source = "registry.terraform.io/hashicorp/random"
      version = "3.6.2"
    }
  }

  backend "gcs" {
    bucket = "epsilonsquare-production-opentofu-state"
    prefix = "infra-production"
  }
}

provider "google" {
  project = var.project_name
  region = var.region
  zone = var.zone
}

provider "kustomization" {
  kubeconfig_raw = local.kube_config
}

provider "kubernetes" {
  host = "https://10.128.0.1:4443"

  client_certificate = tls_locally_signed_cert.kube_admin.cert_pem
  client_key = tls_private_key.kube_admin.private_key_pem
  cluster_ca_certificate = tls_self_signed_cert.ca.cert_pem
}
