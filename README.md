# Semesta

Declarative infrastructure managed with Nix.

This repository is meant to manage multiple machines and services over time.

Today it contains one active host, `vpn`, and currently uses:

- `nixos-anywhere` for first install
- `colmena` for day-2 deploys
- `disko` for disk layout
- self-hosted NetBird on `vpn`

## Layout

```text
semesta/
├── flake.nix
├── AGENTS.md
├── modules/
│   └── nixos/
│       ├── common.nix
│       └── netbird-selfhosted.nix
└── hosts/
    └── vpn/
        ├── configuration.nix
        ├── disko.nix
        ├── hardware-configuration.nix
        ├── netbird.nix
        └── openssh-vpn.nix
```

## Operating Model

```text
Engineer machine
    |
    | edit / validate / deploy
    v
semesta repo
    |
    +--> hosts/<name>/configuration.nix
    +--> hosts/<name>/disko.nix
    +--> hosts/<name>/hardware-configuration.nix
    +--> modules/nixos/*.nix
```

## Current Example

```text
Engineer machine
    |
    | colmena / nixos-rebuild
    v
+-------------------------------+
| vpn                           |
|-------------------------------|
| NixOS                         |
| nginx + ACME                  |
| netbird-server                |
| netbird-dashboard             |
| netbird peer                  |
| route for private subnet      |
+-------------------------------+
    |
    +--> 10.200.0.0/16
```

## Repository Rules

- shared NixOS logic lives in `modules/nixos`
- each machine lives in `hosts/<name>`
- `disko.nix` owns filesystem definitions
- `hardware-configuration.nix` should stay focused on detected hardware details
- stable `nixpkgs` is the default unless explicitly changed
- avoid Home Manager unless explicitly requested

## Current Host Example

- Host name: `vpn`
- Flake target: `.#vpn`
- Managed SSH alias: `semesta-vpn`
- Managed SSH port: `22222`
- NetBird domain: `netbird.pelindungbumi.dev`

## SSH Aliases

Managed hosts are easiest to use with SSH aliases. Example:

```sshconfig
Host semesta-vpn
  HostName 103.125.103.148
  User root
  Port 22222
  IdentityFile ~/.ssh/your-key
  IdentitiesOnly yes
```

Replace `~/.ssh/your-key` with the real private key path you use for the server.

When new hosts are added, use the same pattern with a distinct alias per host.

## First Install

Run from the cloned repo root. Replace host-specific values as needed:

```bash
nix run nixpkgs#nixos-anywhere -- \
  --copy-host-keys \
  --generate-hardware-config nixos-generate-config ./hosts/<host>/hardware-configuration.nix \
  --flake .#<host> \
  --target-host root@<server-ip> \
  -i /path/to/private-key \
  -p 22
```

Notes:

- `hardware-configuration.nix` is generated during first install.
- `disko.nix` owns filesystem layout.
- after install, use the managed SSH settings defined for that host.

## Day-2 Deployment

Preferred:

```bash
nix run github:zhaofengli/colmena -- apply --build-on-target --on <host>
```

Fallback when the local machine has Nix/daemon/architecture issues:

```bash
rsync -az --delete ./ <user>@<ssh-alias>:<checkout-dir>/
ssh <user>@<ssh-alias>
cd <checkout-dir>
sudo nixos-rebuild switch --flake .#<host>
```

## Common Commands

Validate a host locally:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

Deploy a host with Colmena:

```bash
nix run github:zhaofengli/colmena -- apply --build-on-target --on <host>
```

Server-side fallback deploy:

```bash
sudo nixos-rebuild switch --flake .#<host>
```

## Current Service Example: NetBird on `vpn`

NetBird here has two roles on `vpn`:

1. control plane
   - dashboard
   - management API
   - signal/relay
   - STUN

2. peer/router
   - `vpn` itself joins the NetBird mesh
   - `vpn` can route traffic to the private subnet

### Important Difference

These are different things:

- peer access
  - access to a NetBird peer by its NetBird IP, like `vpn.netbird.selfhosted`
- subnet access
  - access to machines behind a routing peer, like `10.200.0.0/16`

If peer access works but subnet access does not, usually check:

- the route is attached to the correct routing peer
- masquerade is enabled on the route/network
- the client peer is allowed by NetBird policy/group assignment

### Current Service Commands

SSH to `vpn`:

```bash
ssh batman@semesta-vpn -p 22222
```

Check current NetBird-related services on `vpn`:

```bash
ssh batman@semesta-vpn -p 22222 'systemctl status nginx netbird-server netbird-dashboard netbird'
```

Check NetBird peer status on `vpn`:

```bash
ssh batman@semesta-vpn -p 22222 'sudo netbird status -d'
```

## NetBird Bootstrap Flow

1. Open:

```text
https://netbird.pelindungbumi.dev/setup
```

2. Create the first admin user.
3. Create a setup key in the NetBird dashboard.
4. Join the `vpn` host as a peer:

```bash
sudo netbird up --management-url https://netbird.pelindungbumi.dev --setup-key <SETUP_KEY> --hostname vpn
```

5. Join a laptop or another device:

```bash
netbird up --management-url https://netbird.pelindungbumi.dev
```

6. For routed subnet access, make sure in NetBird dashboard that:

- the routed subnet is attached to peer `vpn`
- masquerade is enabled
- the client peer/group is allowed to use that route

## Troubleshooting

### Generic

### `hardware-configuration.nix` conflicts with `disko`

If evaluation complains about `fileSystems` conflicts:

- keep storage layout in `hosts/<host>/disko.nix`
- remove `fileSystems.*` and `swapDevices` from `hosts/<host>/hardware-configuration.nix`

### Colmena fails from macOS

This repo may still be deployable from macOS, but local Nix daemon behavior can break `colmena` or `nixos-anywhere` depending on the environment.

When that happens, use the server-side fallback:

```bash
sudo nixos-rebuild switch --flake .#<host>
```

### Service Example: NetBird route does not work

If a peer can ping `vpn.netbird.selfhosted` but cannot reach `10.200.x.x`:

- verify the route is attached to `vpn`
- verify masquerade is enabled
- verify the client has access to the route
- verify the target device on the private subnet actually allows the traffic

## Adding Another Host

Use this checklist:

1. create `hosts/<name>/configuration.nix`
2. create `hosts/<name>/disko.nix`
3. generate `hosts/<name>/hardware-configuration.nix` during first install
4. add the host to `flake.nix`
5. add any reusable logic to `modules/nixos`
6. document any SSH alias or service-specific operational notes here

## Design Rules

- stable `nixpkgs` only unless explicitly requested otherwise
- no Home Manager unless explicitly requested
- shared logic in `modules/nixos`
- host-specific logic in `hosts/<name>`
- keep docs and commands copy-paste friendly
