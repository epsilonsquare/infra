{ pkgs, ... }:

{
  imports = [
    ./hardening.nix
    ./opentofu.nix
    ./servers.nix
    ./users.nix
  ];

  config = {
    environment.systemPackages = with pkgs; [
      bash
      jq
      mosh
    ];
  };
}
