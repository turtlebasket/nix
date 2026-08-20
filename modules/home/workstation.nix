{
  config,
  llm-agents,
  nix-skills,
  git-split-diffs,
  nixvim,
  satellite-nvim,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  llmAgentPackages = llm-agents.packages.${system};
  nixSkills = nix-skills.skills.${system};
  gitSplitDiffsLesskey = pkgs.writeText "git-split-diffs-lesskey" ''
    #command
    f  forw-search \^ ■■ \n
    F  back-search \^ ■■ \n
  '';
  gitSplitDiffsLess = pkgs.less.overrideAttrs (oldAttrs: {
    pname = "git-split-diffs-less";
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace command.c \
        --replace-fail \
          'multi_search(cbuf, (int) number, 0);' \
          'multi_search(cbuf, (int) number, strcmp(cbuf, "^ ■■ ") == 0);'
    '';
  });

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
      nixvimConfig = import ./nixvim-full.nix {
        satelliteNvimSrc = satellite-nvim;
      };
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

  programs.git = {
    enable = true;
    settings = {
      core.pager = "git-split-diffs --color | ${gitSplitDiffsLess}/bin/less --lesskey-src=${gitSplitDiffsLesskey} -A -G -j2 -+LFX";
      split-diffs.theme-name = "auto";
    };
  };

  programs.less = {
    enable = true;
    package = gitSplitDiffsLess;
  };

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
