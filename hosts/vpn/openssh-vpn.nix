{
  ...
}:
{
  services.openssh = {
    enable = true;
    openFirewall = true;
    ports = [ 22222 ];
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      UseDns = false;
      X11Forwarding = false;
    };
  };
}
