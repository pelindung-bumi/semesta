{ ... }:
{
  imports = [ ../../modules/nixos/managed-ssh.nix ];

  services.openssh.ports = [ 22222 ];
}
