resource "null_resource" "nix_config" {
  triggers = {
    hash = join(
      ",",
      [
        for filename
        in fileset("${path.module}/../../nix/server-configurations", "**")
        : filemd5("${path.module}/../../nix/server-configurations/${filename}")
      ])
  }
}

resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_private_key" "cfssl" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_private_key" "service_account" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_private_key" "kube_admin" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "cluster.local"
    organization = "EpsilonSquare"
  }

  validity_period_hours = 24 * 365 * 2

  is_ca_certificate = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "crl_signing",
    "cert_signing",
  ]
}

resource "tls_cert_request" "cfssl" {
  private_key_pem = tls_private_key.cfssl.private_key_pem

  subject {
    common_name  = "cfssl"
    organization = "cfssl"
  }

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_cert_request" "service_account" {
  private_key_pem = tls_private_key.service_account.private_key_pem

  subject {
    common_name  = "cluster.local"
    organization = "system:masters"
  }
}

resource "tls_cert_request" "kube_admin" {
  private_key_pem = tls_private_key.kube_admin.private_key_pem

  subject {
    common_name  = "cluster.local"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "cfssl" {
  cert_request_pem   = tls_cert_request.cfssl.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 24 * 365 * 2

  allowed_uses = [
    "server_auth",
  ]
}

resource "tls_locally_signed_cert" "service_account" {
  cert_request_pem   = tls_cert_request.service_account.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 24 * 365 * 2

  allowed_uses = [
    "client_auth",
  ]
}

resource "tls_locally_signed_cert" "kube_admin" {
  cert_request_pem   = tls_cert_request.kube_admin.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 24 * 365 * 2

  allowed_uses = [
    "client_auth",
  ]
}

# OpenTofu doesn't provide an easy way to generate a random string and hex-encode it.
# Instead, we generate a random string and hash it, since the resulting hash can be
# seen as a valid hex-encoded string.
resource "random_string" "cfssl_auth_token_seed" {
  length = 32
}

resource "wireguard_asymmetric_key" "hydrogen" {}

module "deploy_nixos" {
  source = "github.com/tomferon/terraform-nixos//deploy_nixos?ref=e96dd3edf70f5e10481037024a4ea5490996d18e"
  hermetic = true
  target_user = var.nixos_user
  target_host = var.hydrogen_ip
  ssh_private_key = "-"

  config_pwd = "${path.module}/../../nix/server-configurations"
  config = <<-EOF
  (builtins.getFlake (builtins.toString ./.)).outputs.packages.hydrogen {
    servers = {
      hydrogen = {
        vpnPublicKey = "${wireguard_asymmetric_key.hydrogen.public_key}";
        ipAddress = "${var.hydrogen_ip}";
      };
    };
  }
EOF

  keys = {
    wireguard_private_key = wireguard_asymmetric_key.hydrogen.private_key
    "ca-key.pem" = tls_private_key.ca.private_key_pem
    "ca.pem" = tls_self_signed_cert.ca.cert_pem
    "cfssl-key.pem" = tls_private_key.cfssl.private_key_pem
    "cfssl.pem" = tls_locally_signed_cert.cfssl.cert_pem
    "cfssl-auth-token" = sha256(random_string.cfssl_auth_token_seed.result)
    "kube-service-account-key.pem" = tls_private_key.service_account.private_key_pem
    "kube-service-account.pem" = tls_locally_signed_cert.service_account.cert_pem
    "kube-admin-key.pem" = tls_private_key.kube_admin.private_key_pem
    "kube-admin.pem" = tls_locally_signed_cert.kube_admin.cert_pem
  }

  # Redeploy when any file changes in nix/server-configurations.
  depends_on = [null_resource.nix_config]
}

locals {
  kube_config = <<-EOF
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
