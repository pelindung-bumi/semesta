{ lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
    ./disko.nix
    ./openssh-vpn.nix
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "vpn";

  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
    efiInstallAsRemovable = true;
    efiSupport = true;
  };

  services.resolved.enable = true;

  system.stateVersion = "25.11";
}
