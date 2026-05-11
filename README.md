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

For other module families, expose them through the usual flake outputs, such as `nixosModules` or `darwinModules`, and compose them from the private flake.

## Maintenance

```sh
nix flake show
nix fmt
nix flake check
nix flake update
```
