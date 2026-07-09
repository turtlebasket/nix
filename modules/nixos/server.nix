{ lib, ... }:

{
  imports = [
    ./nix-daemon.nix
  ];

  networking.firewall = {
    enable = lib.mkDefault true;
    allowedTCPPorts = [ 22 ];
  };

  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = lib.mkDefault false;
      KbdInteractiveAuthentication = lib.mkDefault false;
    };
  };
}
