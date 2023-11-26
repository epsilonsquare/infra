{ lib, pkgs, ... }:

let
  administrators = ["tomferon"];
  developers = ["tomferon"];

  users = {
    tomferon = {
      fullName = "Tom Feron";
      sshKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD1VqPyvuxpCESodkWU/du2sRZ3JBWyIPJPjbPGG17570JeRUS8627l6r2wZPN4+lJES1FcRXOxn0IGT3f26A2Z1PVCtyVle6ZIYBDftIHLeTPY0pAG6xc50Ngn03FwiFl9Xn2LXvGg9Zrs0ed0GPeAr88hNzi6lOg8Er3bnNi4/hZK0DPz2lIpzXU50ET7lZl565VYPEBYVHZ1XzrRr4wDRTd0sj2HcKALHB1JJaREZZAw+eqQJNNPCMY0QbgBCUrUd/oOmJ/US+ttwJ+6C5N9AdDJAeh0mxlPKdDAZqIzFehRGL2v4JbCij2MkDO6FO1PqxV60/3HGtUuq73MbGWREi8wvjRKtjXxjZTxBY2owb3Ttf9aTWrEqV4w/lT1QFY2ZKNPCswqwDAr4aeiPwfRvpz4x7ve5Hq4S1OHMyIQweKu+x8Tuv0VjdoaxBi0lbzcZMsXmtHQNQ5KuU1JsswnceQ6NgicN+AyGIPvZowvhqquC6Om/kUMf6VpBdq6BRE="
      ];

      vpnIP = "10.128.128.1";
      vpnPublicKey = "";
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

    users.users = builtins.mapAttrs makeUser users // {
      root.openssh.authorizedKeys.keys =
        builtins.concatMap (username: users.${username}.sshKeys) administrators;
    };

    users.groups = {
      developer = {
        gid = 1001;
        members = developers;
      };

      wheel.members = administrators;
    };
  };
}
