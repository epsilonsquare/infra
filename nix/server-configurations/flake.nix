{
  description = "Configurations for dedicated servers running NixOS";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixpkgs-unstable;

  outputs = { self, nixpkgs }:
    let
      makeSystem = module:
        if builtins.isFunction (module (builtins.functionArgs module))
          then x: makeSystem (module x)
          else
            nixpkgs.lib.nixosSystem {
              modules = [module];
            };
    in
    rec {
      nixosModules = {
        hydrogen = import ./hydrogen.nix;
      };

      packages = {
        hydrogen = makeSystem nixosModules.hydrogen;
      };
    };
}
