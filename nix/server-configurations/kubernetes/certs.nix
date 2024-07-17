{ serverName, ipAddress }:

rec {
  mkCertPath = name: "/var/lib/secrets/${name}.pem";

  mkCert =
    { service
    , action ? "restart"
    , name
    , CN ? "cluster.local"
    , O ? "cluster"
    , owner ? "root"
    , group ? owner
    , mode ? "0600"
    , otherHosts ? []
    , keyUsages ? ["any"]
    }:
    let
      # See https://github.com/cloudflare/certmgr#certificate-specs.
      value = {
        inherit service action;
        authority = {
          remote = "https://127.0.0.1:8888";
          root_ca = "/var/keys/ca.pem";
          profile = "default";
          auth_key_file = "/var/keys/cfssl-auth-token";
        };
        certificate = {
          path = mkCertPath name;
          key_usages = keyUsages;
        };
        private_key = {
          path = mkCertPath "${name}-key";
          inherit owner group mode;
        };
        request = {
          inherit CN;
          hosts = [
            serverName
            ipAddress
            "10.0.0.1"
            "kubernetes"
            "kubernetes.default"
            "kubernetes.default.svc"
            "kubernetes.default.svc.cluster"
            "kubernetes.default.svc.cluster.local"
          ];
          key = {
            algo = "rsa";
            size = 2048;
          };
          names = [{
            inherit O;
            L = "Internet";
          }];
        };
      };
    in
    { inherit name value; };
}
