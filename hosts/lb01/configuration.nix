{ lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/cloud-host.nix
    ../../modules/nixos/managed-ssh.nix
    ../../modules/nixos/remote-builder.nix
    ./disko.nix
    ./nginx-lb.nix
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "lb01";

  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.grub = {
    enable = true;
    configurationLimit = 10;
    device = "/dev/disk/by-id/virtio-592fc87a-c751-479f-9";
    efiInstallAsRemovable = true;
    efiSupport = true;
  };
}
