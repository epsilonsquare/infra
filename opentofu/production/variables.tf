variable "project_name" {}
variable "region" {}
variable "zone" {}

variable "nixos_user" {}
variable "hydrogen_ip" {}

variable "deploy_kubernetes_resources" {
  default = true
  description = "Set to false to apply before the cluster is up and running."
}
