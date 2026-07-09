{
  config,
  nixvim,
  nixvimConfig ? ./nixvim-lite.nix,
  lib,
  pkgs,
  ...
}:
let
  personalCommands = pkgs.runCommand "personal-terminal-commands" { } ''
    install -Dm755 ${../../bin/tmux2} "$out/bin/tmux2"
  '';
in
{
  imports = [
    nixvim.homeModules.nixvim
  ];

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
      (lib.mkOrder 950 ''
        export PATH=${config.programs.nixvim.build.package}/bin:$PATH
      '')
    ];
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ../../config/tmux/tmux.conf;
  };

  programs.btop.enable = true;

  programs.nixvim.imports = [ nixvimConfig ];

  home.file = {
    ".tmux.conf".source = ../../config/tmux/tmux.conf;
  };

  home.packages = [
    pkgs.dua
    personalCommands
  ];
}
