{
  codex-cli-nix,
  claude-code-nix,
  git-split-diffs,
  lib,
  pkgs,
  ...
}:
{
  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    envExtra = ''
      [[ -r "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "tmux"
      ];
      theme = "";
      extraConfig = ''
        zstyle ':omz:update' mode disabled
      '';
    };

    initContent = lib.mkMerge [
      (lib.mkOrder 900 ''
        [[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
      '')
      (lib.mkOrder 1000 ''
        source ${../config/zsh/shared.zsh}
      '')
    ];
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
  };

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ../config/tmux/tmux.conf;
  };

  home.file.".tmux.conf".source = ../config/tmux/tmux.conf;

  xdg.configFile = {
    "nvim/init.lua".source = ../config/neovim/init.lua;
    "nvim/lazy-lock.json".source = ../config/neovim/lazy-lock.json;
  };

  home.packages =
    let
      system = pkgs.stdenv.hostPlatform.system;
      personalScripts = pkgs.runCommand "personal-scripts" { } ''
        install -Dm755 ${../scripts/tmux2} "$out/bin/tmux2"
        install -Dm755 ${../scripts/ntfy-cmd} "$out/bin/ntfy-cmd"
        install -Dm755 ${../scripts/ntfy-msg} "$out/bin/ntfy-msg"
        install -Dm755 ${../scripts/ntfy-osc9} "$out/bin/ntfy-osc9"
      '';
      nixpkgsPackages =
        (with pkgs; [
          basedpyright
          curl
          direnv
          fd
          git
          gnumake
          opencode
          python3
          ripgrep
          rust-analyzer
          stdenv.cc
          svelte-language-server
          typescript-language-server
        ])
        ++ [
          personalScripts
        ];
    in
    [
      claude-code-nix.packages.${system}.claude-code
      codex-cli-nix.packages.${system}.codex
      git-split-diffs.packages.${system}.git-split-diffs
    ]
    ++ nixpkgsPackages;
}
