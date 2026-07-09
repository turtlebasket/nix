{ lib }:
let
  preferredSubstituters = [
    "https://devenv.cachix.org?priority=30"
    "https://cache.numtide.com?priority=30"
  ];

  cacheNixosSubstituter = "https://cache.nixos.org/";

  extraTrustedPublicKeys = [
    "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];

  cacheNixosTrustedPublicKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
in
rec {
  inherit
    preferredSubstituters
    cacheNixosSubstituter
    extraTrustedPublicKeys
    cacheNixosTrustedPublicKey
    ;

  substituters = preferredSubstituters ++ [ cacheNixosSubstituter ];
  trustedPublicKeys = extraTrustedPublicKeys ++ [ cacheNixosTrustedPublicKey ];

  experimentalFeatures = [
    "nix-command"
    "flakes"
  ];

  nixosSettings = {
    substituters = lib.mkBefore substituters;
    trusted-public-keys = lib.mkBefore trustedPublicKeys;
    builders-use-substitutes = true;
    experimental-features = experimentalFeatures;
  };

  nixConf = ''
    substituters = ${lib.concatStringsSep " " substituters}
    trusted-public-keys = ${lib.concatStringsSep " " trustedPublicKeys}
    builders-use-substitutes = true
    experimental-features = ${lib.concatStringsSep " " experimentalFeatures}
  '';
}
