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

resource "wireguard_asymmetric_key" "hydrogen" {}

output "hydrogen_wireguard_public_key" {
  value = wireguard_asymmetric_key.hydrogen.public_key
}

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
  }

  # Redeploy when any file changes in nix/server-configurations.
  depends_on = [null_resource.nix_config]
}
