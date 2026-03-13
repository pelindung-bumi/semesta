{ ... }:
{
  networking.firewall.allowedTCPPorts = [ 6443 ];

  services.k3s = {
    enable = true;
    role = "server";
    disable = [
      "traefik"
      "servicelb"
    ];
    extraFlags = toString [
      "--tls-san=10.200.3.212"
      "--tls-san=10.200.1.93"
      "--tls-san=103.125.102.156"
      "--tls-san=kubeapi.pelindungbumi.dev"
    ];
  };
}
