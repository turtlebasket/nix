{
  config,
  llm-agents,
  git-split-diffs,
  nixvim,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  llmAgentPackages = llm-agents.packages.${system};

  agentSkillTargets = {
    universal = ".agents/skills";
    claudeCode = ".claude/skills";
  };

  defaultAgentSkillTargets = with agentSkillTargets; [
    universal
    claudeCode
  ];

  managedAgentSkills = {
    agent-browser = {
      source = "${llmAgentPackages.agent-browser}/share/agent-browser/skills/agent-browser";
    };
  };

  mkAgentSkillFiles =
    name:
    {
      source,
      targets ? defaultAgentSkillTargets,
      force ? true,
    }:
    lib.genAttrs (map (target: "${target}/${name}") targets) (_: {
      inherit source force;
      recursive = true;
    });

  agentSkillFiles = lib.foldlAttrs (
    files: name: skill:
    files // mkAgentSkillFiles name skill
  ) { } managedAgentSkills;
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
      (lib.mkOrder 1000 ''
        source ${../../config/zsh/shared.zsh}
      '')
    ];
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.nixvim.imports = [ ./nixvim.nix ];

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ../../config/tmux/tmux.conf;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;

    nix-direnv.enable = true;
  };

  home.file = {
    ".tmux.conf".source = ../../config/tmux/tmux.conf;
  }
  // agentSkillFiles;

  home.packages =
    let
      personalCommands = pkgs.runCommand "personal-commands" { } ''
        install -Dm755 ${../../bin/tmux2} "$out/bin/tmux2"
        install -Dm755 ${../../bin/ntfy-cmd} "$out/bin/ntfy-cmd"
        install -Dm755 ${../../bin/ntfy-msg} "$out/bin/ntfy-msg"
        install -Dm755 ${../../bin/ntfy-osc9} "$out/bin/ntfy-osc9"
      '';
      nixpkgsPackages =
        (with pkgs; [
          basedpyright
          curl
          fd
          git
          gnumake
          python3
          ripgrep
          rust-analyzer
          stdenv.cc
          svelte-language-server
          typescript-language-server
        ])
        ++ [
          personalCommands
        ];
    in
    [
      llmAgentPackages.agent-browser
      llmAgentPackages.claude-code
      llmAgentPackages.codex
      llmAgentPackages.opencode
      llmAgentPackages.skills
      git-split-diffs.packages.${system}.git-split-diffs
    ]
    ++ nixpkgsPackages;
}
