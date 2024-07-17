{ lib, config, pkgs, ... }:

let
  cfg = config.epsilonsquare;

  caFile = config.services.cfssl.ca;

  inherit (lib) mkDefault mkIf mkOverride;

  certs = import ./certs.nix {
    serverName = cfg.server.name;
    ipAddress  = cfg.server.vpnIP;
  };

  inherit (certs) mkCertPath mkCert;

  certificates = builtins.listToAttrs [
    (mkCert {
      name = "kubelet";
      service = "kubelet";
      owner = "kubernetes";
      group = "kubernetes";
      CN = "system:node:${cfg.server.name}";
      O = "system:nodes";
    })

    (mkCert {
      name = "kube-proxy";
      service = "kube-proxy";
      owner = "kubernetes";
      group = "kubernetes";
      CN = "system:master:${cfg.server.name}";
      O = "system:masters";
    })
  ];

  masterIPAddress = cfg.firstKubeServer.vpnIP;

in
{
  config = mkIf cfg.server.kubernetes.node {
    services.flannel.enable = false;

    boot.kernel.sysctl."fs.inotify.max_user_instances" = 1048576;

    virtualisation.containerd.settings.plugins = {
      "io.containerd.cri.v1.images".registry.mirrors = {
        "docker.io" = { endpoint = ["https://registry-1.docker.io"]; };
        "10.0.0.253:5000" = { endpoint = ["http://10.0.0.253:5000"]; };
      };
    };

    services.kubernetes = {
      roles = ["node"];
      easyCerts = false;
      inherit caFile;

      # Using mkDefault so that it's overwritable in ./master.nix.
      masterAddress = mkDefault masterIPAddress; # FIXME: Use DNS?

      kubeconfig = {
        inherit caFile;
        certFile = mkCertPath "kubelet";
        keyFile = mkCertPath "kubelet-key";
        server = "https://${masterIPAddress}:4443";
      };

      kubelet = {
        address = cfg.server.vpnIP;
        clientCaFile = caFile;
        hostname = cfg.server.name;
        nodeIp = cfg.server.vpnIP;
        tlsCertFile = mkCertPath "kubelet";
        tlsKeyFile = mkCertPath "kubelet-key";
        clusterDns = config.services.kubernetes.addons.dns.clusterIp;

        # FIXME: --pod-cidr is deprecated. See logs.
        extraOpts = "--pod-cidr ${cfg.server.kubernetes.podCidr}";

        cni.config = [
          {
            cniVersion = "0.3.1";
            name = "kube";
            type = "bridge";
            bridge = "kube0";
            isDefaultGateway = true;
            forceAddress = false;
            ipMasq = true;
            hairpinMode = true;
            ipam = {
              type = "host-local";
              subnet = cfg.server.kubernetes.podCidr;
            };
          }
        ];

        kubeconfig = {
          inherit caFile;
          certFile = mkCertPath "kubelet";
          keyFile = mkCertPath "kubelet-key";
          server = "https://${masterIPAddress}:4443";
        };
      };

      proxy  = {
        enable = true;
        bindAddress = cfg.server.vpnIP;

        kubeconfig = {
          inherit caFile;
          certFile = mkCertPath "kube-proxy";
          keyFile = mkCertPath "kube-proxy-key";
          server = "https://${masterIPAddress}:4443";
        };
      };
    };

    services.certmgr = {
      enable = true;
      specs = certificates;
    };
    # Without the following line, it certmgr-pre-start fails. This wasn't needed
    # before and it will probably be fixed in the future, so this should be revisited.
    systemd.services.certmgr.path = [pkgs.bash];

    networking.firewall.allowedTCPPorts = [80 443];

    networking.firewall.interfaces.wg0 = {
      allowedTCPPorts = [
        10250 # kubelet
      ];
    };

    networking.firewall.trustedInterfaces = ["wg0" "kube0"];
  };
}
