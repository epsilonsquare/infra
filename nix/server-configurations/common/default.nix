{ ... }:

{
  imports = [
    ./hardening.nix
    ./opentofu.nix
    ./servers.nix
    ./users.nix
  ];
}
