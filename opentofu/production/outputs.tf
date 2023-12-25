output "hydrogen_wireguard_public_key" {
  value = wireguard_asymmetric_key.hydrogen.public_key
}

output "kube_config" {
  sensitive = true

  value = <<-EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://10.128.0.1:4443
    certificate-authority-data: ${base64encode(tls_self_signed_cert.ca.cert_pem)}
  name: e2
contexts:
- context:
    cluster: e2
    user: e2-admin
  name: e2
current-context: e2
users:
- name: e2-admin
  user:
    client-certificate-data: ${base64encode(tls_locally_signed_cert.kube_admin.cert_pem)}
    client-key-data: ${base64encode(tls_private_key.kube_admin.private_key_pem)}
preferences: {}
EOF
}
