{ lib, config, pkgs, ... }:

let
  cfg = config.epsilonsquare;

  caFile = config.services.cfssl.ca;
  caKeyFile = config.services.cfssl.caKey;

  isInitNode = cfg.firstKubeServer.name == cfg.serverName;

  otherMasterServers =
    builtins.filter
      (server:
        server.name != cfg.serverName && server.kubernetes.master != null)
      (builtins.attrValues cfg.servers);

  inherit (lib) mkIf;

  certs = import ./certs.nix {
    serverName = cfg.server.name;
    ipAddress  = cfg.server.vpnIP;
  };

  inherit (certs) mkCertPath mkCert;

  certificates =
    let
      etcd = mkCert {
        name = "etcd";
        service = "etcd";
        owner = "etcd";
        group = "root";
      };

      kubeApiServer = mkCert {
        name = "kube-apiserver";
        service = "kube-apiserver";
        owner = "kubernetes";
        group = "kubernetes";
        CN = "system:master:${cfg.serverName}";
        O = "system:masters";
      };

      kubeScheduler = mkCert {
        name = "kube-scheduler";
        service = "kube-scheduler";
        owner = "kubernetes";
        group = "kubernetes";
        CN = "system:master:${cfg.serverName}";
        O = "system:masters";
      };

      kubeControllerManager = mkCert {
        name = "kube-controller-manager";
        service = "kube-controller-manager";
        owner = "kubernetes";
        group = "kubernetes";
        CN = "system:master:${cfg.serverName}";
        O = "system:masters";
      };

      kubeAddonManager = mkCert {
        name = "kube-addon-manager";
        service = "kube-addon-manager";
        owner = "kubernetes";
        group = "kubernetes";
        CN = "system:master:${cfg.serverName}";
        O = "system:masters";
      };

    in
    builtins.listToAttrs [
      etcd
      kubeApiServer
      kubeScheduler
      kubeControllerManager
      kubeAddonManager
    ];

  etcdCommonConfig = {
    name = cfg.serverName;
    advertiseClientUrls = ["https://${cfg.server.vpnIP}:2379"];
    certFile = mkCertPath "etcd";
    clientCertAuth = true;
    initialAdvertisePeerUrls = ["https://${cfg.server.vpnIP}:2380"];
    keyFile = mkCertPath "etcd-key";
    listenClientUrls = ["https://${cfg.server.vpnIP}:2379"];
    listenPeerUrls = ["https://${cfg.server.vpnIP}:2380"];
    peerCertFile = mkCertPath "etcd";
    peerClientCertAuth = true;
    peerKeyFile = mkCertPath "etcd-key";
    peerTrustedCaFile = caFile;
    trustedCaFile = caFile;
  };

  etcdInitConfig = {
    initialClusterState = "new";
    initialCluster = [
      "${cfg.firstKubeServer.name}=https://${cfg.firstKubeServer.vpnIP}:2380"
    ];
  };

  etcdOtherConfig = {
    initialClusterState = "existing";
    initialCluster =
      let
        takeUntil = pred: list:
          (pkgs.lib.lists.foldr
            (x: { acc, found }:
              let
                found' = found || pred x;
              in
              if found'
                then { acc = [x] ++ acc; found = found'; }
                else { inherit acc found; }
            ) { acc = []; found = false; } list).acc;
      in
      ["${cfg.firstKubeServer.name}=https://${cfg.firstKubeServer.vpnIP}:2380"]
      ++ builtins.map
          ({ name, vpnIP, ... }: "${name}=https://${vpnIP}:2380")
          (builtins.filter
            ({ name, ... }: name != cfg.firstKubeServer.name)
            (takeUntil ({ serverName, ...}: serverName == cfg.name)
              (builtins.filter
                ({ kubernetes, ... }: kubernetes.master != null)
                (builtins.attrValues cfg.servers))));
  };

  etcdConfig =
    etcdCommonConfig //
    (if isInitNode then etcdInitConfig else etcdOtherConfig);

in
{
  config = mkIf (cfg.server.kubernetes.master != null) {
    services.kubernetes = {
      roles = ["master"];
      easyCerts = false;

      inherit caFile;

      masterAddress = cfg.server.vpnIP;

      apiserver = {
        enable = true;

        advertiseAddress = cfg.server.vpnIP;
        bindAddress = cfg.server.vpnIP;
        securePort = 4443;
        clientCaFile = caFile;
        kubeletClientCaFile = caFile;
        kubeletClientCertFile = mkCertPath "kube-apiserver";
        kubeletClientKeyFile = mkCertPath "kube-apiserver-key";
        proxyClientCertFile = mkCertPath "kube-apiserver";
        proxyClientKeyFile = mkCertPath "kube-apiserver-key";
        tlsCertFile = mkCertPath "kube-apiserver";
        tlsKeyFile = mkCertPath "kube-apiserver-key";
        serviceAccountKeyFile = "/var/keys/kube-service-account-key.pem";
        serviceAccountSigningKeyFile = "/var/keys/kube-service-account-key.pem";
        allowPrivileged = true;

        extraOpts = ''
          --service-node-port-range=1-65535
        '';

        etcd = {
          inherit caFile;
          servers = ["https://${cfg.server.vpnIP}:2379"];
          certFile = mkCertPath "kube-apiserver";
          keyFile = mkCertPath "kube-apiserver-key";
        };
      };

      scheduler = {
        enable = true;
        address = cfg.server.vpnIP;

        kubeconfig = {
          inherit caFile;
          certFile = mkCertPath "kube-scheduler";
          keyFile = mkCertPath "kube-scheduler-key";
          server = "https://${cfg.server.vpnIP}:4443";
        };
      };

      controllerManager = {
        enable = true;
        bindAddress = cfg.server.vpnIP;
        rootCaFile = caFile;
        tlsCertFile = mkCertPath "kube-controller-manager";
        tlsKeyFile = mkCertPath "kube-controller-manager-key";
        serviceAccountKeyFile = "/var/keys/kube-service-account-key.pem";
        allocateNodeCIDRs = false;

        extraOpts = builtins.concatStringsSep " " [
          "--cluster-signing-cert-file"
          caFile
          "--cluster-signing-key-file"
          caKeyFile
        ];

        kubeconfig = {
          inherit caFile;
          certFile = mkCertPath "kube-controller-manager";
          keyFile = mkCertPath "kube-controller-manager-key";
          server = "https://${cfg.server.vpnIP}:4443";
        };
      };

      addons = {
        dns = {
          enable = true;
          replicas = 1; # FIXME: Bump to 3 on a full-fledged cluster.
        };
      };

      addonManager.enable = true;
    };

    # FIXME: After the refactoring of the Kube code in NixOS/nixpkgs, some stuff
    # was moved to the PKI module even though it's not related to it. This
    # breaks CoreDNS (deployed by the addon manager) when the PKI module is not
    # enabled. The following code fixes the issue.
    # systemd.services.kube-addon-manager = {
    #   environment.KUBECTL_OPTS =
    #     builtins.concatStringsSep " " [
    #       "--server https://${cfg.server.vpnIP}:4443"
    #       "--certificate-authority ${caFile}"
    #       "--client-certificate ${mkCertPath "kube-addon-manager"}"
    #       "--client-key ${mkCertPath "kube-addon-manager-key"}"
    #     ];
    #   serviceConfig.PermissionsStartOnly = true;
    #   preStart = with pkgs;
    #     let
    #       files =
    #         lib.mapAttrsToList
    #           (n: v: writeText "${n}.json" (builtins.toJSON v))
    #           config.services.kubernetes.addonManager.bootstrapAddons;
    #     in
    #     ''
    #       ${pkgs.sudo}/bin/sudo -u kubernetes -g kubernetes \
    #         ${kubectl}/bin/kubectl $KUBECTL_OPTS \
    #         apply -f ${builtins.concatStringsSep " \\\n -f " files}
    #     '';
    # };
    #
    services.certmgr = {
      enable = true;
      specs = certificates;
    };

    services.etcd = etcdConfig;

    # Etcd might fail because the VPN is not up, we don't have the certs or
    # because the init node hasn't added this node as a member yet.
    # This unit should restart until it works.
    systemd.services.etcd = {
      serviceConfig = {
        RestartSec = "10";
        Restart = "always";
        # Never trigger the start limit.
        StartLimitIntervalSec = "1";
        StartLimitBurst = "5";
      };

      # FIXME: This should be fixed in NixOS/nixpkgs.
      # environment = {
      #   ETCD_PEER_CLIENT_CERT_AUTH = "1";
      # };
    };

    systemd.services.etcd-init = mkIf isInitNode {
      enable = true;

      reloadIfChanged = true;
      wantedBy = ["multi-user.target"];
      requires = ["network.target"];
      serviceConfig = {
        RestartSec = "5";
        Restart = "on-failure";
        # Never trigger the start limit.
        StartLimitIntervalSec = "1";
        StartLimitBurst = "5";
      };

      path = with pkgs; [etcd gnugrep];

      script = ''
        ctl() {
          etcdctl \
            --endpoints https://${cfg.firstKubeServer.vpnIP}:2379 \
            --ca-file ${caFile} \
            --cert-file ${mkCertPath "etcd"} \
            --key-file ${mkCertPath "etcd-key"} \
            "$@"
        }
        add_member() {
          local name="$1"
          local addr="$2"
          (ctl member list | grep "$name") || \
            ctl member add "$name" "https://$addr:2380"
          while true; do
            (ctl member list | grep "$name") && break || sleep 5
          done
        }
        ${builtins.concatStringsSep "\n" (builtins.map
            ({ serverName, vpnIP, ... }: "add_member ${serverName} ${vpnIP}")
          otherMasterServers)}
      '';
    };

    networking.firewall.interfaces.wg0 = {
      allowedTCPPorts = [
        2379 2380 # etcd
        4443 # apiserver
      ];
    };
  };
}
