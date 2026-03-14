{ lib, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = true;
    ports = lib.mkDefault [ 22 ];
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      UseDns = false;
      X11Forwarding = false;
    };
  };
}
