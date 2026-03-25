{
  config,
  lib,
  pkgs,
  ...
}:
let
  cacheDomain = "nixtip.pelindungbumi.dev";
  cacheKeyName = "${cacheDomain}-1";
  secretsDir = "/var/lib/secrets/harmonia";
  secretKeyPath = "${secretsDir}/${cacheKeyName}.secret";
  publicKeyPath = "${secretsDir}/${cacheKeyName}.pub";
in
{
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "admin@pelindungbumi.dev";

  nix.settings.trusted-users = lib.mkForce [
    "root"
    "@wheel"
    "cachepush"
  ];

  services.harmonia-dev.cache = {
    enable = true;
    signKeyPaths = [ secretKeyPath ];
    settings = {
      bind = "127.0.0.1:5000";
      priority = 30;
    };
  };

  systemd.services.harmonia-signing-key = {
    description = "Bootstrap Harmonia signing key";
    wantedBy = [ "multi-user.target" ];
    before = [ "harmonia-dev.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.coreutils ];
    script = ''
      install -d -m 0750 "${secretsDir}"

      if [ ! -s "${secretKeyPath}" ] || [ ! -s "${publicKeyPath}" ]; then
        tmpdir=$(mktemp -d)
        trap 'rm -rf "$tmpdir"' EXIT

        ${lib.getExe' config.nix.package "nix-store"} --generate-binary-cache-key \
          "${cacheKeyName}" \
          "$tmpdir/cache.secret" \
          "$tmpdir/cache.pub"

        install -m 0400 "$tmpdir/cache.secret" "${secretKeyPath}"
        install -m 0644 "$tmpdir/cache.pub" "${publicKeyPath}"
      fi
    '';
  };

  systemd.services.harmonia-dev = {
    after = [ "harmonia-signing-key.service" ];
    requires = [ "harmonia-signing-key.service" ];
  };

  users.users.cachepush = {
    isNormalUser = true;
    description = "Remote cache upload user";
    home = "/var/lib/cachepush";
    createHome = true;
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [ ];
  };
}
