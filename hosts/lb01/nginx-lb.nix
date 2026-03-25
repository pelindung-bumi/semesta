{ ... }:
let
  cacheDomain = "nixtip.pelindungbumi.dev";
in
{
  services.nginx = {
    enable = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "${cacheDomain}" = {
        enableACME = true;
        forceSSL = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
          {
            addr = "127.0.0.1";
            port = 8443;
            ssl = true;
          }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:5000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_redirect http:// https://;
          '';
        };
      };

      "_" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
            extraParameters = [ "default_server" ];
          }
        ];
        locations."/" = {
          proxyPass = "http://10.200.0.177:30080";
          proxyWebsockets = true;
        };
      };
    };
    streamConfig = ''
      map $ssl_preread_server_name $https_backend {
        ${cacheDomain} 127.0.0.1:8443;
        default 10.200.0.177:30443;
      }

      server {
        listen 443;
        proxy_pass $https_backend;
        ssl_preread on;
      }

      server {
        listen 6443;
        proxy_pass 10.200.0.177:6443;
      }
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
    6443
  ];
}
