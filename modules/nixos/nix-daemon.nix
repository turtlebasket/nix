{ lib, ... }:
let
  nixDaemon = import ../../lib/nix-daemon.nix { inherit lib; };
in
{
  nix.settings = nixDaemon.nixosSettings;
}
