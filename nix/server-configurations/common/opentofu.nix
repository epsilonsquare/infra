{ lib, ... }:

let
  inherit (lib) mkOption;
  inherit (lib.types) attrsOf submodule str;

  serverNames = ["hydrogen"];

  serverOptions =
    let
      option = mkOption {
        type = submodule {
          vpnPublicKey = mkOption {
            type = str;
            description = "WireGuard public key of that server.";
          };

          ipAddress = mkOption {
            type = str;
            description = "Real IP address of that server.";
          };
        };
      };
    in
    builtins.listToAttrs (map (name: { name = name; value = option; }) serverNames);

in
{
  options.epsilonsquare.opentofu = mkOption {
    description = "Configuration coming from OpenTofu.";

    type = submodule {
      options = {
        servers = serverOptions;
      };
    };
  };
}
