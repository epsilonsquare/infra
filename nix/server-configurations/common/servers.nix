{ lib, config, ... }:

let
  cfg = config.epsilonsquare;

  servers = {
    hydrogen = {
      realIP = cfg.epsilonsquare.opentofu.hydrogen_ip;
      vpnIP = "10.128.0.1";
      vpnPublicKey = ""; #cfg.terraform.vpnKeys.hydrogen;

      kubernetes = {
        master = 1;
        node = true;
        podCidr = "10.1.1.0/24";
      };
    };
  };

  server = cfg.servers.${cfg.serverName};
  firstKubeServer =
    builtins.head (builtins.filter
      (srv: srv.kubernetes.master == 1) (builtins.attrValues cfg.servers));

  inherit (lib) mkEnableOption mkOption;
  inherit (lib.types) attrsOf submodule str int nullOr;

  realIPOption = mkOption {
    type = str;
    description = "Server's actual IP address accessible from outside.";
  };

  vpnIPOption = mkOption {
    type = str;
    description = "IP address in the VPN of the form 10.128.0.N.";
  };

  vpnPublicKeyOption = mkOption {
    type = str;
    description = "WireGuard public key. Should be passed by Terraform.";
  };

  podCidrOption = mkOption {
    type = str;
    description = "CIDRs used by pods started on this node of form '10.1.N.0/24'";
  };

  serverSubmodule = submodule ({ name, ... }: {
    options = {
      name = mkOption {
        type = str;
        description = "Name of this server. Defaults to the attribute key.";
        default = name;
      };

      realIP = realIPOption;
      vpnIP = vpnIPOption;
      vpnPublicKey = vpnPublicKeyOption;

      kubernetes = mkOption {
        type = submodule {
          options = {
            master = mkOption {
              type = nullOr int;
              description = """
                Integer 'n' such that it is the nth server running the
                Kubernetes API server added to the cluster.
              """;
              default = null;
            };

            node = mkEnableOption "Run Kubelet to let pods be started on this server.";
            podCidr = podCidrOption;
          };
        };
      };
    };
  });

in
{
  options.epsilonsquare = {
    serverName = mkOption {
      type = str;
      description = "Name of this server. Should match a key in the attribute sets of servers.";
    };

    servers = mkOption {
      type = attrsOf serverSubmodule;
    };

    server = mkOption {
      type = serverSubmodule;
      description = """
        Configuration of this server as in 'epsilonsquare.servers' according to
        the server name set in 'epsilonsquare.serverName'.
      """;
    };

    firstKubeServer = mkOption {
      type = serverSubmodule;
      description = "First Kubernetes master node to initialise the cluster.";
    };
  };

  config = {
    epsilonsquare.server = server;
    epsilonsquare.servers = servers;
    epsilonsquare.firstKubeServer = firstKubeServer;
  };
}
