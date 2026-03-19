{ lib, ... }:
{
  nix.settings = {
    max-jobs = lib.mkDefault "auto";
    trusted-users = lib.mkDefault [
      "root"
      "@wheel"
    ];
  };
}
