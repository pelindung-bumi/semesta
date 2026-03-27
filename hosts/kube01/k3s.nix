{ pkgs, ... }:
let
  pinnedK3s = pkgs.callPackage ../../pkgs/k3s.nix { };
in
{
  networking.firewall.allowedTCPPorts = [ 6443 ];

  services.k3s = {
    enable = true;
    package = pinnedK3s;
    role = "server";
    disable = [
      "kube-proxy"
      "traefik"
      "servicelb"
    ];
    extraFlags = toString [
      "--flannel-backend=none"
      "--disable-network-policy"
      "--tls-san=10.200.0.177"
      "--tls-san=10.200.1.93"
      "--tls-san=103.125.102.156"
      "--tls-san=kubeapi.pelindungbumi.dev"
    ];
  };
}
