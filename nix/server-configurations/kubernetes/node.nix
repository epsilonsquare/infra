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

    # The first part of the settings come from
    # NixOS/nixpkgs:nixos/modules/services/cluster/kubernetes/default.nix
    virtualisation.containerd.configFile = pkgs.writeText "containerd.toml" ''
      version = 2
      root = "/var/lib/containerd"
      state = "/run/containerd"
      oom_score = 0
      [grpc]
        address = "/run/containerd/containerd.sock"
      [plugins."io.containerd.grpc.v1.cri"]
        sandbox_image = "pause:latest"
      [plugins."io.containerd.grpc.v1.cri".cni]
        bin_dir = "/opt/cni/bin"
        max_conf_num = 0
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes."io.containerd.runc.v2".options]
        SystemdCgroup = true

      [plugins."io.containerd.grpc.v1.cri".registry]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
          [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
            endpoint = ["https://registry-1.docker.io"]
          [plugins."io.containerd.grpc.v1.cri".registry.mirrors."10.0.0.253:5000"]
            endpoint = ["http://10.0.0.253:5000"]
    '';

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

        extraOpts = "--pod-cidr ${cfg.server.kubernetes.podCidr}";

        cni.config = [{
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
        }];

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

    networking.firewall.allowedTCPPorts = [80 443];

    networking.firewall.interfaces.wg0 = {
      allowedTCPPorts = [
        10250 # kubelet
      ];
    };

    networking.firewall.trustedInterfaces = ["wg0" "kube0"];
  };
}
