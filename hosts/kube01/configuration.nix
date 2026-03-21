{ config, lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/cloud-host.nix
    ../../modules/nixos/managed-ssh.nix
    ./disko.nix
    ./k3s.nix
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "kube01";

  boot.kernelModules = [
    "libceph"
    "rbd"
    "nbd"
  ];

  system.activationScripts.exposeKernelModules.text = ''
    mkdir -p /lib/modules
    ln -sfn \
      "/run/current-system/kernel-modules/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}" \
      "/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}"
  '';

  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.grub = {
    enable = true;
    configurationLimit = 10;
    device = "/dev/disk/by-id/virtio-f3decaab-8f0e-4181-8";
    efiInstallAsRemovable = true;
    efiSupport = true;
  };
}
