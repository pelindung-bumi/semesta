# AGENTS

This repository manages infrastructure declaratively with Nix.

## Scope

- Use `nixos-anywhere` for first installs.
- Use `colmena` for day-2 deployments.
- Do not introduce Home Manager unless the user explicitly asks for it.

## Structure Rules

- Keep shared NixOS logic in `modules/nixos`.
- Keep each machine in `hosts/<name>`.
- Each host directory should contain at least `configuration.nix` and `disko.nix`.
- Let `nixos-anywhere --generate-hardware-config` create `hosts/<name>/hardware-configuration.nix` during first install.
- Keep Colmena deployment metadata in `flake.nix` unless a host needs something more complex.

## Channel Policy

- Stable `nixpkgs` is the default for the operating system.
- Do not add `nixpkgs-unstable` unless the user explicitly asks for it.

## Host Conventions

- The first server host is `vpn`.
- Use `#vpn` for flake targets.
- Use a non-default SSH port for managed hosts unless the user asks otherwise.
- Keep host-specific services such as custom OpenSSH policy inside the host directory when they are not shared by all machines.
- Preserve headless/cloud access during changes: key-based SSH, serial console, and conservative networking defaults.

## Remote Workflow

- Inspect the target host before editing host-specific config.
- Record disk layout, boot mode, interface name, MAC, addressing, and the chosen install disk before writing `disko`.
- For cloud VMs, prefer simple DHCP networking unless the provider requires static config.

## Safety Rules

- Never run destructive install or disk-formatting commands unless the user is explicitly at the execution step.
- Local commands are for validation only unless the user asks for deployment.
- Preserve SSH access on remote hosts when changing networking or OpenSSH settings.

## Validation Workflow

- Validate with `nix flake check` when possible.
- Build the target system with `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` before asking the user to deploy.
- Keep install commands copy-paste friendly in the final response.
