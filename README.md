# nix

Reusable personal Nix modules.

This repo is public and host-agnostic. It is for reusable module code and shared defaults; private flakes own users, hosts, machines, and secrets.

## Use

Add this repo as a flake input:

```nix
inputs.nix.url = "github:turtlebasket/nix";
```

For Home Manager hosts, build each host with this repo's helper:

```nix
homeConfigurations.<host> = nix.lib.mkHomeConfiguration {
  system = "<system>";
  username = "<user>";
  modules = [
    nix.homeManagerModules.workstation
    ./hosts/<host>.nix
  ];
};
```

Use `nix.homeManagerModules.terminal` for shell/tmux/btop/dua/neovim hosts, such as jump boxes.
Use `nix.homeManagerModules.workstation` for full interactive machines; it imports `terminal` and adds LSP, Treesitter, language tooling, and agent packages.

For NixOS hosts, compose system modules from `nixosModules`:

```nix
nixosConfigurations.<host> = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    nix.nixosModules.server
    ./hosts/<host>/system.nix
  ];
};
```

`nix.nixosModules.server` includes the shared Nix daemon policy, openssh defaults, and firewall port 22. The daemon policy configures preferred substituters, trusted public keys, `builders-use-substitutes`, and `experimental-features = nix-command flakes`. For NixOS hosts that only need the daemon policy, import `nix.nixosModules.nix-daemon`.

For plain Linux servers with multi-user Nix, such as Ubuntu machines, NixOS modules cannot be applied by Home Manager. Treat daemon-level Nix settings as a host bootstrap step in the private config repo. This repo exposes the shared settings as `lib.nixDaemon.nixConf` so private bootstrap code can install the same daemon policy into `/etc/nix/nix.conf`.

## Maintenance

```sh
nix flake show
nix fmt
nix flake check
nix flake update
```
