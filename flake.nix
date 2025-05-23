{
  description = "Infrastructure";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixpkgs-unstable;
  inputs.flake-utils.url = github:numtide/flake-utils;

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = {
          terraform = import ./nix/overlays/terraform.nix;
        };

        pkgs = builtins.foldl'
          (acc: overlay: acc.extend overlay)
          nixpkgs.legacyPackages.${system}
          (builtins.attrValues overlays);

      in
      {
        inherit overlays;

        devShell = import ./nix/shell.nix {
          inherit pkgs;
        };
      }
    );

}
