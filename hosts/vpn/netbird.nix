{
  ...
}:
{
  imports = [ ../../modules/nixos/netbird-selfhosted.nix ];

  semesta.services.netbirdSelfhosted = {
    enable = true;
    acmeEmail = "admin@pelindungbumi.dev";
    domain = "netbird.pelindungbumi.dev";
    localPeer.enable = true;
  };
}
