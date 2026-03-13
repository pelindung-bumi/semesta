{ ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/virtio-2a457a0e-9dc1-4972-b";
      content = {
        type = "gpt";
        partitions = {
          bios = {
            size = "1M";
            type = "EF02";
            priority = 1;
          };

          esp = {
            size = "512M";
            type = "EF00";
            priority = 2;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot/efi";
              mountOptions = [ "umask=0077" ];
            };
          };

          boot = {
            size = "1G";
            priority = 3;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/boot";
            };
          };

          root = {
            size = "100%";
            priority = 4;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
