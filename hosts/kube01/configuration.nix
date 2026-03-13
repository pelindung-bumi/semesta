{ lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/cloud-host.nix
    ../../modules/nixos/managed-ssh.nix
    ./disko.nix
    ./k3s.nix
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "kube01";

  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.grub = {
    enable = true;
    configurationLimit = 10;
    device = "/dev/disk/by-id/virtio-2a457a0e-9dc1-4972-b";
    efiInstallAsRemovable = true;
    efiSupport = true;
  };
}
