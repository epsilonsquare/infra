opentofu: { ... }:

{
  imports = [
    (import ./hardware-configurations/hydrogen.nix)
    (import ./common)
    (import ./vpn)
    (import ./pki)
    (import ./kubernetes)
  ];

  config = {
    networking.hostName = "hydrogen";
    epsilonsquare.serverName = "hydrogen";
    epsilonsquare.opentofu = opentofu;
  };
}
