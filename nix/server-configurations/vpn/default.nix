{ config, ... }:

let
  cfg = config.epsilonsquare;

  peers = builtins.attrValues
    (builtins.removeAttrs cfg.servers [cfg.serverName]);

  clients =
    builtins.filter
      (user: user.vpnIP != null && user.vpnPublicKey != null)
      (builtins.attrValues cfg.users);

  makeClient = client: {
    allowedIPs = [client.vpnIP];
    persistentKeepalive = 25;
    publicKey = client.vpnPublicKey;
  };

  makePeer = peer: {
    allowedIPs = [peer.vpnIP peer.kubernetes.podCidr];
    endpoint = "${peer.realIP}:500";
    publicKey = peer.vpnPublicKey;
  };

in
{
  boot.kernelModules = ["wireguard"];

  networking.firewall.allowedUDPPorts = [500];
  networking.firewall.allowedTCPPorts = [500];

  networking.wireguard.interfaces.wg0 = {
    ips = [cfg.server.vpnIP];
    listenPort = 500;
    privateKeyFile = "/var/keys/wireguard_private_key";
    peers = map makePeer peers ++ map makeClient clients;
  };

  networking.nat = {
    enable = true;
    internalInterfaces = ["wg0"];
  };

  networking.extraHosts = builtins.concatStringsSep "\n"
    (map ({ name, vpnIP, ... }: "${vpnIP} ${name}") (builtins.attrValues cfg.servers));
}
