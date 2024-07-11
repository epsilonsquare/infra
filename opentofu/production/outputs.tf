output "hydrogen_wireguard_public_key" {
  value = wireguard_asymmetric_key.hydrogen.public_key
}

output "kube_config" {
  sensitive = true
  value = local.kube_config
}
