{ lib, pkgs, ... }:

let
  administrators = ["tomferon"];
  developers = ["tomferon"];

  users = {
    tomferon = {
      fullName = "Tom Feron";
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRQaocoynSackpsZXgxPF4o9E0Uhr0yTaEFbKExISZK"
      ];

      vpnIP = "10.128.128.1";
      vpnPublicKey = "aRc4ie2HWkLpyOaDrR+ApR9Czokf6MY+2cjFr355vm0=";
    };
  };

  makeUser = username: { fullName, sshKeys ? [], ... }: {
    description = fullName;
    openssh.authorizedKeys.keys = sshKeys;
    createHome = true;
    home = "/home/${username}";
    isNormalUser = true;
    shell = pkgs.bashInteractive;
  };

in
{
  options.epsilonsquare = {
    users = with lib; mkOption {
      type = with lib.types; attrsOf (submodule {
        options = {
          fullName = mkOption {
            type = str;
            description = "The actual name of that person.";
          };

          sshKeys = mkOption {
            type = str;
            description = "SSH public key(s).";
          };

          vpnIP = mkOption {
            type = nullOr str;
            description = "IP address of that user in the VPN, should be 10.128.128.X.";
            default = null;
          };

          vpnPublicKey = mkOption {
            type = nullOr str;
            description = "WireGuard's public key of that user.";
            default = null;
          };
        };
      });
    };
  };

  config = {
    epsilonsquare.users = users; # Share with other modules, e.g. vpn.

    services.openssh.enable = true;
    services.openssh.settings.PasswordAuthentication = false;

    users.users = builtins.mapAttrs makeUser users;

    users.groups = {
      developer = {
        gid = 1001;
        members = developers;
      };

      wheel.members = administrators;
    };

    security.sudo = {
      enable = true;
      execWheelOnly = true;
      wheelNeedsPassword = false;
    };
  };
}
