{
  config,
  lib,
  ...
}:

let
  cfg = config.services.eternal-terminal;
in
{
  imports = [
    ./server.nix
  ];

  services.eternal-terminal.enable = lib.mkDefault true;

  networking.firewall.allowedTCPPorts = lib.mkIf cfg.enable [ cfg.port ];
}
