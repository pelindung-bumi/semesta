{ pkgs, ... }:
let
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA1o1nNUy6D8Zzp2TO9QcIesrWDfEwvvXRVPUg2KVOY4 rivaldo@Rivaldos-MacBook-Pro.local"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDGO20/Ht5z1qfuOH5jcbQ+U73KhiE3VQ/KwcMwSIkPpNjhXTSgJ6DVetZGTx6ro3i+xjRsQoT1VRHwWurno/UKP7wPz9fNumVkXxqcUUyh+XK92VUeBpEW/7aVCgDU/v+kuGlNpf2IEkabqKHQp6V8CnwcLHTOC9qPcBx4I4ThebZDAmIlCHXf2qS86Kl/sO3qtpAIAcxWvDyFcUYKKcWBtOc6DnsU3xXgzb1ZBE1Rct53BqlpBm8xH1XaFQPgkN8wD9yUeJsn0ICyvWs4qRop2iSC9S/C8EGDH2b86iA49PTh54xIEC8TQ46/7bsnlnrMy96P42M44E6UPW7o2St1gE9kHqmHQqCamr0s9dvK9GdhVGYfAKo8crTkA81/Q4icyGI2X9AiPK+Q40PQpOu0ftihVbBeN47ObYp8QiVuybA4XiomPd4Bmyr+2MxS5rrRcDqBo86Yp79rMBUqFq2EAIxjp3SFT51pfM2U5dXiS94vx8WrcygkUV4o5P7OuJjnpBHIDoTZfjkrqXGS2njRoCHk/kmTu7XkKAtoWxb2D9nmGIhxUB4siNbKo02UDYjvi7GMfwRbUU2szPDXfVARkhToxRC1zuAxzsn7QIayvgV1P4xqSxDSXQax6Lo5NX3gryTdERAu7a12NZ9lFAgPIGQTTTDWqLPQDyFDGA9vvQ== leo"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHX1IQvSFe97+h2q6l4A4fUkzrBPyisqg2vC56Pz+QE0 rolando@rolnap0lapwin0"
  ];
in
{
  boot.loader.timeout = 3;
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
  ];
  boot.loader.grub.extraConfig = ''
    serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
    terminal_input console serial
    terminal_output console serial
  '';

  console.keyMap = "us";
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "UTC";

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    inetutils
    iperf3
    jq
    mtr
    nmap
    tcpdump
    traceroute
    vim
  ];

  networking.firewall.enable = true;

  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = false;
  system.stateVersion = "25.11";

  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = authorizedKeys;
  };

  users.users.batman = {
    isNormalUser = true;
    description = "Batman";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    hashedPassword = "!";
    openssh.authorizedKeys.keys = authorizedKeys;
  };
}
