{
  config,
  nixvim,
  nixvimConfig ? ./nixvim-lite.nix,
  lib,
  pkgs,
  ...
}:
let
  yamlFormat = pkgs.formats.yaml { };
  rodConfig =
    pkgs.writeTextDir
      (
        if pkgs.stdenv.isDarwin then
          "Library/Application Support/rod/config.toml"
        else
          ".config/rod/config.toml"
      )
      ''
        fallback_to_light = false
      '';
  terminalTheme = pkgs.writeShellApplication {
    name = "terminal-theme";
    runtimeInputs = [ pkgs.rod ];
    text = ''
      if [ "$(HOME=${rodConfig} rod print)" = Light ]; then
        printf 'light\n'
      else
        printf 'dark\n'
      fi
    '';
  };
  mkBtopConfig = variant: ''
    #? Config file for btop v.${pkgs.btop.version}
    color_theme = "flexoki-${variant}"
    theme_background = false
  '';
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

    shellAliases = {
      btop = ''command ${pkgs.btop}/bin/btop --config "${config.xdg.configHome}/btop/flexoki-$(${terminalTheme}/bin/terminal-theme).conf"'';
      glow = ''command ${pkgs.glow}/bin/glow -s "$(${terminalTheme}/bin/terminal-theme)"'';
    };
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

  programs.lsd.enable = true;

  programs.nixvim.imports = [ nixvimConfig ];

  home.file = {
    ".tmux.conf".source = ../../config/tmux/tmux.conf;
  };

  home.sessionVariables.GLOW_CONFIG_HOME = "${config.xdg.configHome}/glow";

  xdg.configFile = {
    "btop/flexoki-dark.conf".text = mkBtopConfig "dark";
    "btop/flexoki-light.conf".text = mkBtopConfig "light";
    "glow/glow.yml".source = yamlFormat.generate "glow.yml" {
      all = false;
      mouse = true;
      pager = true;
      style = "auto";
      width = 140;
    };
  };

  home.packages = [
    pkgs.bat
    pkgs.dua
    pkgs.glow
    pkgs.jq
    pkgs.librespeed-cli
    personalCommands
    terminalTheme
    pkgs.yq-go
  ];
}
