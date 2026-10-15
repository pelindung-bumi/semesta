{
  description = "Semesta infrastructure managed declaratively with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-config.url = "github:valdo766hi/nix-config?dir=outputs/pi";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    disko,
    colmena,
    nix-config,
    ...
  }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;

      mkPkgs = system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ colmena.overlays.default ];
        };

      piModule = { pkgs, ... }: {
        environment.systemPackages = [ nix-config.packages.${pkgs.stdenv.hostPlatform.system}.pi ];
      };

      hosts = {
        lb01 = {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            piModule
            ./hosts/lb01/configuration.nix
          ];
          deployment = {
            targetHost = "semesta-lb01";
            targetPort = 22;
            targetUser = "batman";
            privilegeEscalationCommand = [ "sudo" "-H" "--" ];
            tags = [ "lb01" "loadbalancer" ];
          };
        };

        kube01 = {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            piModule
            ./hosts/kube01/configuration.nix
          ];
          deployment = {
            targetHost = "semesta-kube01";
            targetPort = 22;
            targetUser = "batman";
            privilegeEscalationCommand = [ "sudo" "-H" "--" ];
            tags = [ "kube01" "k3s" ];
          };
        };

        vpn = {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            piModule
            ./hosts/vpn/configuration.nix
          ];
          deployment = {
            targetHost = "semesta-vpn";
            targetPort = 22222;
            targetUser = "batman";
            privilegeEscalationCommand = [ "sudo" "-H" "--" ];
            tags = [ "vpn" ];
          };
        };
      };
    in
    {
      formatter = forAllSystems (system: (mkPkgs system).nixfmt-rfc-style);

      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.git
              pkgs.just
              pkgs.nixfmt-rfc-style
              pkgs.nil
              pkgs.nixos-anywhere
              pkgs.openssh
            ]
            ++ lib.optionals (builtins.hasAttr system colmena.packages && builtins.hasAttr "default" colmena.packages.${system}) [ colmena.packages.${system}.default ]
            ++ lib.optionals (pkgs ? colmena) [ pkgs.colmena ];
          };
        }
      );

      nixosConfigurations = lib.mapAttrs (
        _name: host:
        lib.nixosSystem {
          inherit (host) system;
          modules = host.modules;
        }
      ) hosts;

      colmena = {
        meta = {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
          machinesFile = ./colmena/machines;
        };
      }
      // lib.mapAttrs (
        _name: host:
        {
          imports = host.modules;
          deployment = host.deployment // {
            allowLocalDeployment = true;
          };
        }
      ) hosts;

      colmenaHive = colmena.lib.makeHive self.outputs.colmena;

    };
}
