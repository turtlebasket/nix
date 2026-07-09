{
  description = "Reusable personal Nix modules";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim.url = "github:nix-community/nixvim";

    llm-agents.url = "github:numtide/llm-agents.nix";

    git-split-diffs = {
      url = "github:turtlebasket/git-split-diffs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixvim,
      llm-agents,
      git-split-diffs,
      ...
    }:
    let
      darwinSystem = "aarch64-darwin";
      linuxSystem = "x86_64-linux";

      nixpkgsConfig = {
        config.allowUnfree = true;
      };

      systems = [
        darwinSystem
        linuxSystem
      ];

      forSystems =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f system;
          }) systems
        );

      nixDaemon = import ./lib/nix-daemon.nix { lib = nixpkgs.lib; };

      mkHomeDirectory =
        { system, username }:
        if nixpkgs.lib.hasSuffix "-darwin" system then "/Users/${username}" else "/home/${username}";

      homeManagerModules = rec {
        workstation =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          import ./modules/home/workstation.nix {
            inherit
              config
              llm-agents
              git-split-diffs
              nixvim
              lib
              pkgs
              ;
          };

        default = workstation;
      };

      nixosModules = rec {
        nix-daemon = ./modules/nixos/nix-daemon.nix;
        server = ./modules/nixos/server.nix;

        default = server;
      };

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          inherit (nixpkgsConfig) config;
        };

      mkFormatter =
        system:
        let
          pkgs = mkPkgs system;
        in
        pkgs.writeShellApplication {
          name = "nix-fmt";
          runtimeInputs = [ pkgs.nixfmt ];
          text = ''
            if [ "$#" -gt 0 ]; then
              exec nixfmt "$@"
            fi

            find . -name '*.nix' -not -path './.git/*' -exec nixfmt {} +
          '';
        };

      mkHomeConfiguration =
        {
          system,
          username,
          homeDirectory ? mkHomeDirectory { inherit system username; },
          modules ? [ homeManagerModules.workstation ],
          extraSpecialArgs ? { },
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          inherit extraSpecialArgs;
          modules = [
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.stateVersion = "25.05";
            }
          ]
          ++ modules;
        };
    in
    {
      formatter = forSystems mkFormatter;

      inherit homeManagerModules nixosModules;

      lib = {
        inherit mkHomeConfiguration mkHomeDirectory nixDaemon;
      };
    };
}
