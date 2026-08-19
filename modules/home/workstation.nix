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
  gitSplitDiffsLesskeySource = pkgs.writeText "git-split-diffs-lesskey-source" ''
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
  gitSplitDiffsLesskey = pkgs.runCommand "git-split-diffs-lesskey" { } ''
    ${gitSplitDiffsLess}/bin/lesskey -o "$out" ${gitSplitDiffsLesskeySource}
  '';

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

  agentSkillDirectLinks = lib.concatMap (
    name:
    let
      skill = managedAgentSkills.${name};
      targets = skill.targets or defaultAgentSkillTargets;
    in
    map (target: {
      inherit (skill) source;
      path = "${target}/${name}";
    }) targets
  ) (lib.attrNames managedAgentSkills);
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

  home.activation.migrateLegacyAgentSkillDirectories = lib.hm.dag.entryBefore [ "linkGeneration" ] (
    lib.concatMapStringsSep "\n" (skill: ''
      skill_path="$HOME/${skill.path}"

      if [[ -d "$skill_path" && ! -L "$skill_path" ]]; then
        skill_manifest_target="$(${pkgs.coreutils}/bin/readlink "$skill_path/SKILL.md" 2>/dev/null || true)"

        case "$skill_manifest_target" in
          /nix/store/*)
            ;;
          *)
            echo "Refusing to replace unmanaged agent skill directory: $skill_path" >&2
            exit 1
            ;;
        esac

        legacy_backup=${lib.escapeShellArg "${config.xdg.stateHome}/nix-personal/legacy-agent-skills/${skill.path}"}

        if [[ -e "$legacy_backup" || -L "$legacy_backup" ]]; then
          echo "Agent skill migration backup already exists: $legacy_backup" >&2
          exit 1
        fi

        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir --parents "$(${pkgs.coreutils}/bin/dirname "$legacy_backup")"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$skill_path" "$legacy_backup"
      fi
    '') agentSkillDirectLinks
  );

  # Codex follows a symlinked skill directory, but not Home Manager's usual
  # two-hop directory link through the generation's home-files tree.
  home.activation.linkAgentSkillsDirectly = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    lib.concatMapStringsSep "\n" (skill: ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln --symbolic --force --no-dereference \
        ${lib.escapeShellArg (toString skill.source)} \
        "$HOME/${skill.path}"
    '') agentSkillDirectLinks
  );

  xdg.configFile."git/nix-personal.config".text = ''
    [core]
      pager = git-split-diffs --color | ${gitSplitDiffsLess}/bin/less --lesskey-file=${gitSplitDiffsLesskey} -A -G -j2 -+LFX
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
