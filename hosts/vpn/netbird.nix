{
  ...
}:
{
  imports = [ ../../modules/nixos/netbird-selfhosted.nix ];

  semesta.services.netbirdSelfhosted = {
    enable = true;
    domain = "netbird.pelindungbumi.dev";
    localPeer.enable = true;
  };
}
