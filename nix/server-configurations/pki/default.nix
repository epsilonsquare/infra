{ config, pkgs, lib, ... }:

{
  services.cfssl = {
    enable = true;

    ca = "/var/keys/ca.pem";
    caKey = "/var/keys/ca-key.pem";
  };

  # FIXME: Files in /var/keys should be copied to other locations with the
  # appropriate user, group and permissions instead of this.
  users.groups.keys.members = ["kubernetes" "cfssl" "etcd"];
}
