{ ... }:
{
  services.nginx = {
    enable = true;
    streamConfig = ''
      server {
        listen 6443;
        proxy_pass 10.200.0.177:6443;
      }
      server {
        listen 80;
        proxy_pass 10.200.0.177:30080;
      }
      server {
        listen 443;
        proxy_pass 10.200.0.177:30443;
      }
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 443 6443 ];
}
