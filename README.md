# Semesta

Declarative infrastructure managed with Nix.

This repository is meant to manage multiple machines and services over time.

Today it contains these host roles:

- `vpn` for self-hosted NetBird
- `lb01` for nginx edge routing, Harmonia, and Kubernetes API proxying
- `kube01` for a minimal single-node k3s cluster

Pinned service versions in the current setup:

- NetBird server image: `0.66.4`
- NetBird dashboard image: `v2.34.2`
- K3s binary: `v1.35.1+k3s1`
- Harmonia cache: `v3.0.0` via upstream flake input

It currently uses:

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
│       ├── cloud-host.nix
│       ├── common.nix
│       ├── managed-ssh.nix
│       ├── netbird-selfhosted.nix
│       └── ...
└── hosts/
    ├── lb01/
    │   ├── configuration.nix
    │   ├── disko.nix
    │   ├── harmonia.nix
    │   ├── hardware-configuration.nix
    │   └── nginx-lb.nix
    ├── kube01/
    │   ├── configuration.nix
    │   ├── disko.nix
    │   ├── hardware-configuration.nix
    │   └── k3s.nix
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
- prefer plain upstream NixOS options over custom wrapper options

## Current Host Example

- Host name: `vpn`
- Flake target: `.#vpn`
- Managed SSH alias: `semesta-vpn`
- Managed SSH port: `22222`
- NetBird domain: `netbird.pelindungbumi.dev`

Current planned hosts:

```text
vpn    -> NetBird control plane + peer/router
lb01   -> nginx edge routing + Harmonia + kube API TCP proxy
kube01 -> single-node k3s server
```

Current host endpoints:

```text
vpn    -> private: 10.200.2.108   public: 103.125.103.148   ssh: 22222
lb01   -> private: 10.200.1.93    public: 103.125.102.156   ssh: 22
kube01 -> private: 10.200.0.177   public: 103.125.103.90    ssh: 22
```

## SSH Aliases

Managed hosts are easiest to use with SSH aliases. Current example matching this repo:

```sshconfig
Host semesta-vpn
  HostName 103.125.103.148
  User batman
  Port 22222
  IdentityFile ~/.ssh/your-key
  IdentitiesOnly yes

Host semesta-lb01
  HostName 10.200.1.93
  User batman
  Port 22
  IdentityFile ~/.ssh/your-key
  IdentitiesOnly yes

Host semesta-kube01
  HostName 10.200.0.177
  User batman
  Port 22
  IdentityFile ~/.ssh/your-key
  IdentitiesOnly yes
```

This repo's `flake.nix` uses `semesta-lb01`, `semesta-kube01`, and `semesta-vpn` as `deployment.targetHost` values, so these aliases need to exist in your local `~/.ssh/config`.

Replace `~/.ssh/your-key` with the real private key path you use for the server.

When new hosts are added, use the same pattern with a distinct alias per host.

## Remote Builder

This repo now includes a Colmena machines file at `colmena/machines` that points builds to `lb01` through the `batman` user and the `semesta-lb01` SSH alias.

Current builder entry:

```text
ssh-ng://batman@semesta-lb01 x86_64-linux - 2 2 big-parallel
```

`colmena` uses that file through `meta.machinesFile` in `flake.nix`, so the normal day-2 deployment path becomes:

Day-2 deployments also log in as `batman` and escalate with `sudo`, instead of SSHing as `root` directly.

```bash
nix run github:zhaofengli/colmena -- apply --on <host>
```

### Local Machine Requirements

Your local machine still needs working SSH access to `batman@semesta-lb01`. With the SSH aliases above, a quick validation is:

```bash
ssh semesta-lb01
```

If you use a multi-user Nix install, make sure your local user is trusted by the Nix daemon. Example:

```text
trusted-users = root <your-local-username>
```

Add that to your local `/etc/nix/nix.conf` if needed, then restart the local Nix daemon using the method for your platform.

Optional dedicated builder alias example:

```sshconfig
Host semesta-builder
  HostName 10.200.1.93
  User batman
  Port 22
  IdentityFile ~/.ssh/your-key
  IdentitiesOnly yes
```

### Remote Builder Validation

First, make sure the builder host config evaluates locally:

```bash
nix build .#nixosConfigurations.lb01.config.system.build.toplevel
```

Then test direct remote build delegation from the local machine by asking `lb01` to build another host closure:

```bash
nix build .#nixosConfigurations.lb01.config.system.build.toplevel \
  --builders 'ssh-ng://batman@semesta-lb01 x86_64-linux - 2 2 big-parallel' \
  --max-jobs 0
```

For a stronger end-to-end check against a non-builder target:

```bash
nix build .#nixosConfigurations.kube01.config.system.build.toplevel \
  --builders 'ssh-ng://batman@semesta-lb01 x86_64-linux - 2 2 big-parallel' \
  --max-jobs 0
```

`--max-jobs 0` forces the build off the local machine so it is easier to confirm the builder path is working.

## Harmonia Cache on `lb01`

`lb01` also exposes a public Harmonia cache at:

```text
https://nixtip.pelindungbumi.dev
```

Current edge routing on `lb01` is:

```text
80/tcp  -> nixtip.pelindungbumi.dev -> local Harmonia
80/tcp  -> any other Host          -> kube01:30080
443/tcp -> SNI nixtip...           -> local Harmonia TLS vhost
443/tcp -> any other SNI/default   -> kube01:30443
6443    -> kube01:6443
```

Notes:

- keep the Cloudflare `A` record for `nixtip.pelindungbumi.dev` pointed at `103.125.102.156`
- keep that DNS record DNS-only so ACME `http-01` renewal and SSH uploads stay simple
- Harmonia runs on loopback on `lb01`; public TLS terminates at NixOS `nginx`
- cache uploads are intended to use the dedicated SSH user `cachepush`

### Deploy and Verify

Build the `lb01` system locally first:

```bash
nix build .#nixosConfigurations.lb01.config.system.build.toplevel
```

Then deploy with Colmena:

```bash
nix run github:zhaofengli/colmena -- apply --build-on-target --on lb01
```

Verify the public cache endpoint:

```bash
curl -fsSL https://nixtip.pelindungbumi.dev/nix-cache-info
```

Verify the services on `lb01`:

```bash
ssh semesta-lb01 'sudo systemctl status nginx harmonia-dev harmonia-signing-key --no-pager'
```

### Public Cache Key

The Harmonia signing keypair is created automatically on first deploy and stored only on `lb01`:

```text
secret: /var/lib/secrets/harmonia/nixtip.pelindungbumi.dev-1.secret
public: /var/lib/secrets/harmonia/nixtip.pelindungbumi.dev-1.pub
```

Read the public key after the first deployment:

```bash
ssh semesta-lb01 'sudo cat /var/lib/secrets/harmonia/nixtip.pelindungbumi.dev-1.pub'
```

### Laptop Client Example

Add the cache manually on the laptop after you read the public key:

```nix
{
  nix.settings = {
    substituters = [ "https://nixtip.pelindungbumi.dev" ];
    trusted-public-keys = [ "nixtip.pelindungbumi.dev-1:<PASTE_PUBLIC_KEY_HERE>" ];
  };
}
```

### GitHub Actions Upload Flow

The cache server is public over HTTPS, but build uploads should go straight to `lb01` over private NetBird SSH into its Nix store.

Example flow:

```bash
nix build .#some-output
nix copy --to ssh-ng://cachepush@10.200.1.93 ./result
```

Notes:

- GitHub Actions should join NetBird first using the repository secret `NETBIRD_SETUP_KEY`
- add the GitHub Actions SSH public key to `users.users.cachepush.openssh.authorizedKeys.keys` before using CI uploads
- `cachepush` is trusted by the Nix daemon on `lb01`, but it is not a sudo user
- SSH uploads should stay on the private NetBird address `10.200.1.93`; only cache downloads use the public HTTPS endpoint

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

Current install examples:

```bash
nix run nixpkgs#nixos-anywhere -- \
  --copy-host-keys \
  --generate-hardware-config nixos-generate-config ./hosts/lb01/hardware-configuration.nix \
  --flake .#lb01 \
  --target-host root@10.200.1.93 \
  -p 22
```

```bash
nix run nixpkgs#nixos-anywhere -- \
  --copy-host-keys \
  --generate-hardware-config nixos-generate-config ./hosts/kube01/hardware-configuration.nix \
  --flake .#kube01 \
  --target-host root@10.200.0.177 \
  -p 22
```

## Day-2 Deployment

Preferred:

```bash
nix run github:zhaofengli/colmena -- apply --on <host>
```

Fallback when the local machine cannot use the remote builder cleanly:

```bash
nix run github:zhaofengli/colmena -- apply --build-on-target --on <host>
```

Fallback when the local machine has Nix/daemon/architecture issues beyond that:

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
nix run github:zhaofengli/colmena -- apply --on <host>
```

Deploy a host with the old build-on-target path:

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

### Service Example: kube API through `lb01`

`lb01` now has two edge roles:

- public HTTP/S routing for `nixtip.pelindungbumi.dev` and kube ingress traffic
- Kubernetes API TCP proxying on `6443`

The Kubernetes API path is still:

```text
client -> lb01:6443 -> kube01:6443
```

`kube01` includes API certificate SANs for:

- `10.200.0.177`
- `10.200.1.93`
- `103.125.102.156`
- `kubeapi.pelindungbumi.dev`

That means kube clients can safely use any of these API endpoints after install:

- `https://10.200.0.177:6443`
- `https://10.200.1.93:6443`
- `https://103.125.102.156:6443`
- `https://kubeapi.pelindungbumi.dev:6443`

If kube API is unreachable through `lb01`, check:

- `lb01` can reach `10.200.0.177:6443`
- `services.nginx` is active on `lb01`
- `services.k3s` is active on `kube01`
- firewall allows `6443/tcp` on both hosts

### Service Example: Harmonia on `lb01`

If `https://nixtip.pelindungbumi.dev` is unreachable or does not serve cache metadata, check:

- the `A` record for `nixtip.pelindungbumi.dev` still points to `103.125.102.156`
- the record remains DNS-only so ACME `http-01` can renew
- `services.nginx` and `harmonia-dev` are active on `lb01`
- `curl -fsSL https://nixtip.pelindungbumi.dev/nix-cache-info` returns metadata
- `sudo cat /var/lib/secrets/harmonia/nixtip.pelindungbumi.dev-1.pub` returns the public key you installed on the laptop

### Service Example: `kube01` storage layout

`kube01` intentionally leaves the extra disk raw for future Rook/Ceph use:

- `vda` = operating system disk managed by `disko`
- `vdb` = untouched raw disk reserved for future Ceph

## Adding Another Host

Use this checklist:

1. create `hosts/<name>/configuration.nix`
2. create `hosts/<name>/disko.nix`
3. generate `hosts/<name>/hardware-configuration.nix` during first install
4. add the host to `flake.nix`
5. add any reusable logic to `modules/nixos`
6. document any SSH alias or service-specific operational notes here

## TODO

- add final SSH aliases for all managed hosts in local `~/.ssh/config`
- optionally update `flake.nix` deployment targets to use SSH aliases for `lb01` and `kube01`
- document the final kubeconfig distribution workflow for `kubeapi.pelindungbumi.dev:6443`
- evaluate future migration from flannel to Cilium on `kube01`
- reserve future Ceph/Rook plan for the extra raw disk on a future storage-capable Kubernetes host

## Design Rules

- stable `nixpkgs` only unless explicitly requested otherwise
- no Home Manager unless explicitly requested
- shared logic in `modules/nixos`
- host-specific logic in `hosts/<name>`
- keep docs and commands copy-paste friendly
