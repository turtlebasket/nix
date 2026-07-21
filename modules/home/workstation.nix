{
  config,
  llm-agents,
  nix-skills,
  git-split-diffs,
  nixvim,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  llmAgentPackages = llm-agents.packages.${system};
  nixSkills = nix-skills.skills.${system};

  agentSkillTargets = {
    universal = ".agents/skills";
    claudeCode = ".claude/skills";
    codex = ".codex/skills";
  };

  defaultAgentSkillTargets = with agentSkillTargets; [
    universal
    claudeCode
    codex
  ];

  managedAgentSkills = {
    # Discovery stub that defers to `agent-browser skills get` for content
    agent-browser.source = nixSkills.vercel-labs.agent-browser.agent-browser;
    frontend-design.source = nixSkills.anthropics.skills.frontend-design;
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
    (import ./terminal.nix {
      inherit
        config
        nixvim
        lib
        pkgs
        ;
      nixvimConfig = ./nixvim-full.nix;
    })
  ];

  programs.zsh.initContent = lib.mkOrder 1000 ''
    source ${../../config/zsh/shared.zsh}
  '';

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;

    nix-direnv.enable = true;
  };

  home.file = agentSkillFiles;

  xdg.configFile."git/nix-personal.config".text = ''
    [core]
      pager = git-split-diffs --color | less -+LFX
    [split-diffs]
      theme-name = auto
  '';

  home.activation.includeNixPersonalGitConfig =
    lib.hm.dag.entryAfter
      [
        "installPackages"
        "linkGeneration"
      ]
      ''
        include_path="~/.config/git/nix-personal.config"

        if ! ${pkgs.git}/bin/git config --global --get-all include.path \
          | ${pkgs.gnugrep}/bin/grep --fixed-strings --line-regexp --quiet "$include_path"; then
          $DRY_RUN_CMD ${pkgs.git}/bin/git config --global --add include.path "$include_path"
        fi
      '';

  home.packages =
    let
      personalCommands = pkgs.runCommand "personal-workstation-commands" { } ''
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
