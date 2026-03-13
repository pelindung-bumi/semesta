{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.semesta.services.netbirdSelfhosted;

  baseUrl = "http://${cfg.domain}";
  stateDir = "/var/lib/netbird-server";
  dataDir = "${stateDir}/data";
  renderedDir = "${stateDir}/rendered";
  secretsDir = "${stateDir}/secrets";
  serverConfigPath = "${renderedDir}/config.yaml";
in
{
  options.semesta.services.netbirdSelfhosted = {
    enable = mkEnableOption "self-hosted NetBird control plane";

    domain = mkOption {
      type = types.str;
      example = "netbird.example.com";
      description = "Public domain used by the NetBird control plane.";
    };

    serverImage = mkOption {
      type = types.str;
      default = "docker.io/netbirdio/netbird-server:latest";
      description = "OCI image for the combined NetBird server.";
    };

    dashboardImage = mkOption {
      type = types.str;
      default = "docker.io/netbirdio/dashboard:latest";
      description = "OCI image for the NetBird dashboard.";
    };

    localPeer.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the NetBird client on the same host for later peer registration.";
    };

    localPeer.setupKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/var/lib/secrets/netbird/setup-key";
      description = "Optional setup-key file used to auto-register the local peer after the control plane is ready.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      netbird
      openssl
    ];

    networking.firewall.allowedTCPPorts = [ 80 ];
    networking.firewall.allowedUDPPorts = [ 3478 ];

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      virtualHosts.${cfg.domain} = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
        };

        locations."~ ^/(relay|ws-proxy/)" = {
          proxyPass = "http://127.0.0.1:8081";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_read_timeout 1d;
          '';
        };

        locations."~ ^/(signalexchange\\.SignalExchange|management\\.ManagementService|management\\.ProxyService)/".extraConfig = ''
          grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          grpc_pass grpc://127.0.0.1:8081;
          grpc_read_timeout 1d;
          grpc_send_timeout 1d;
          grpc_socket_keepalive on;
        '';

        locations."~ ^/(api|oauth2)/" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header Host $host;
          '';
        };

        extraConfig = ''
          client_header_timeout 1d;
          client_body_timeout 1d;
        '';
      };
    };

    services.logrotate.settings.nginx.su = "root root";

    systemd.services.netbird-server-secrets = {
      description = "Generate persistent secrets for self-hosted NetBird";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [
        coreutils
        openssl
      ];
      script = ''
        install -d -m 0700 "${secretsDir}" "${renderedDir}" "${dataDir}"

        if [ ! -s "${secretsDir}/auth-secret" ]; then
          openssl rand -hex 32 > "${secretsDir}/auth-secret"
          chmod 600 "${secretsDir}/auth-secret"
        fi

        if [ ! -s "${secretsDir}/store-encryption-key" ]; then
          openssl rand -base64 32 > "${secretsDir}/store-encryption-key"
          chmod 600 "${secretsDir}/store-encryption-key"
        fi
      '';
    };

    systemd.services.netbird-server-config = {
      description = "Render self-hosted NetBird configuration";
      after = [ "netbird-server-secrets.service" ];
      requires = [ "netbird-server-secrets.service" ];
      before = [
        "netbird-server.service"
        "netbird-dashboard.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.coreutils ];
      script = ''
        auth_secret=$(tr -d '\n' < "${secretsDir}/auth-secret")
        store_key=$(tr -d '\n' < "${secretsDir}/store-encryption-key")

        install -d -m 0700 "${renderedDir}" "${dataDir}"

        cat > "${serverConfigPath}" <<EOF
server:
  listenAddress: ":80"
  exposedAddress: "${baseUrl}:80"
  stunPorts:
    - 3478
  metricsPort: 9090
  healthcheckAddress: ":9000"
  logLevel: "info"
  logFile: "console"
  authSecret: "$auth_secret"
  dataDir: "/var/lib/netbird"
  auth:
    issuer: "${baseUrl}/oauth2"
    signKeyRefreshEnabled: true
    dashboardRedirectURIs:
      - "${baseUrl}/nb-auth"
      - "${baseUrl}/nb-silent-auth"
    cliRedirectURIs:
      - "http://localhost:53000/"
  store:
    engine: "sqlite"
    dsn: ""
    encryptionKey: "$store_key"
EOF

        chmod 600 "${serverConfigPath}"
      '';
    };

    virtualisation.oci-containers.containers = {
      netbird-server = {
        serviceName = "netbird-server";
        image = cfg.serverImage;
        ports = [
          "127.0.0.1:8081:80"
          "3478:3478/udp"
        ];
        volumes = [
          "${dataDir}:/var/lib/netbird"
          "${serverConfigPath}:/etc/netbird/config.yaml:ro"
        ];
        cmd = [
          "--config"
          "/etc/netbird/config.yaml"
        ];
      };

      netbird-dashboard = {
        serviceName = "netbird-dashboard";
        image = cfg.dashboardImage;
        ports = [ "127.0.0.1:8080:80" ];
        environment = {
          NETBIRD_MGMT_API_ENDPOINT = baseUrl;
          NETBIRD_MGMT_GRPC_API_ENDPOINT = baseUrl;
          AUTH_AUDIENCE = "netbird-dashboard";
          AUTH_CLIENT_ID = "netbird-dashboard";
          AUTH_CLIENT_SECRET = "";
          AUTH_AUTHORITY = "${baseUrl}/oauth2";
          USE_AUTH0 = "false";
          AUTH_SUPPORTED_SCOPES = "openid profile email groups";
          AUTH_REDIRECT_URI = "/nb-auth";
          AUTH_SILENT_REDIRECT_URI = "/nb-silent-auth";
          NGINX_SSL_PORT = "443";
          LETSENCRYPT_DOMAIN = "none";
        };
      };
    };

    systemd.services.netbird-server = {
      after = [ "netbird-server-config.service" ];
      requires = [ "netbird-server-config.service" ];
    };

    systemd.services.netbird-dashboard = {
      after = [
        "netbird-server-config.service"
        "netbird-server.service"
      ];
      requires = [
        "netbird-server-config.service"
        "netbird-server.service"
      ];
    };

    services.netbird = mkIf cfg.localPeer.enable {
      useRoutingFeatures = "both";
      clients.default = {
        port = 51820;
        interface = "wt0";
        hardened = true;
        autoStart = false;
        environment = {
          NB_ADMIN_URL = baseUrl;
          NB_MANAGEMENT_URL = baseUrl;
        };
        login.enable = cfg.localPeer.setupKeyFile != null;
        login.setupKeyFile = cfg.localPeer.setupKeyFile;
      };
    };
  };
}
