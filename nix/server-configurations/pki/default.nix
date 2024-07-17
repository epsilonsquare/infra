{ config, pkgs, lib, ... }:

{
  services.cfssl = {
    enable = true;

    ca = "/var/keys/ca.pem";
    caKey = "/var/keys/ca-key.pem";

    tlsCert = "/var/keys/cfssl.pem";
    tlsKey = "/var/keys/cfssl-key.pem";

    configFile = toString (pkgs.writeText "cfssl-config.json" (builtins.toJSON {
      signing = {
        profiles = {
          default = {
            usages = ["any"];
            auth_key = "default";
            expiry = "720h";
          };
        };
      };
      auth_keys = {
        default = {
          type = "standard";
          key = "file:/var/keys/cfssl-auth-token";
        };
      };
    }));
  };

  # FIXME: Files in /var/keys should be copied to other locations with the
  # appropriate user, group and permissions instead of this.
  users.groups.keys.members = ["kubernetes" "cfssl" "etcd"];
}
