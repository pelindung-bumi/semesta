# AGENTS

This repository manages infrastructure declaratively with Nix.

## Scope

- Use `nixos-anywhere` for first installs.
- Use `colmena` for day-2 deployments.
- Do not introduce Home Manager unless the user explicitly asks for it.
- Use NixOS modules from `modules/nixos` for reusable logic and keep host-specific service wiring inside `hosts/<name>`.

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
- Use `#<host>` for flake targets.
- Use a non-default SSH port for managed hosts unless the user asks otherwise.
- Keep host-specific services such as custom OpenSSH policy inside the host directory when they are not shared by all machines.
- Preserve headless/cloud access during changes: key-based SSH, serial console, and conservative networking defaults.
- For `vpn`, the managed SSH port is `22222` unless the user changes it.
- Prefer simple built-in NixOS services first; only add custom wrappers/modules when the upstream module is clearly insufficient.

## Service Rules

- Keep shared service logic in `modules/nixos`.
- Keep host-specific service wiring in `hosts/<name>`.
- Prefer readable, upstream-aligned configuration over overabstracted custom modules.
- When a service has both a control plane and an agent/peer role, model them as separate concerns.

## NetBird Rules

- `netbird.pelindungbumi.dev` is the self-hosted NetBird domain on `vpn`.
- Keep NixOS `nginx` as the reverse proxy and TLS terminator for NetBird unless the user asks for a different proxy.
- Use ACME with `http-01` for this host unless the user explicitly wants DNS challenge or external certificate management.
- Treat the NetBird control plane and the NetBird peer as separate concerns:
  - control plane: dashboard, management, signal/relay, STUN
  - peer: `services.netbird.enable = true` on hosts that should join the mesh
- For routed private networks, the routing peer must be the machine that can actually reach that subnet.
- When a user reports that a routed subnet is unreachable, check in this order:
  - the routing peer is connected
  - the route is attached to the correct peer
  - masquerade is enabled when the routed subnet does not know how to return traffic to NetBird IPs
  - the client peer is allowed by NetBird policy/group assignment
  - the target device itself allows the requested traffic
- Remember that peer access and subnet access are different things:
  - peer access targets the peer's NetBird IP/FQDN
  - subnet access targets networks behind a routing peer

## Deployment Notes

- Prefer `colmena apply --build-on-target --on <host>` for day-2 changes from a compatible local environment.
- If `colmena` fails because of local/macOS/daemon-specific issues, use a server-side fallback: `nixos-rebuild switch --flake .#<host>` from a checkout on the target host.
- When using SSH aliases for managed hosts, keep the alias in `deployment.targetHost` and document the matching `~/.ssh/config` expectation in `README.md`.
- Keep generated files and secrets out of git unless the user explicitly asks otherwise.
- Document current operational commands in `README.md` whenever a new host or service is added.

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
- When `disko` is used, let `disko.nix` own filesystem definitions and keep `hardware-configuration.nix` limited to hardware detection details.
