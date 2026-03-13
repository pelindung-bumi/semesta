{ ... }:
{
  services.nginx = {
    enable = true;
    streamConfig = ''
      server {
        listen 6443;
        proxy_pass 10.200.3.212:6443;
      }
    '';
  };

  networking.firewall.allowedTCPPorts = [ 6443 ];
}
