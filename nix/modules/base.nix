{ config, lib, pkgs, ... }:
{
  # Base configuration for all Fabric-managed machines
  
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Auto-optimize store
  nix.settings.auto-optimise-store = true;
  
  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # System packages available on all hosts
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    tmux
    jq
    dig
    tcpdump
    iperf3
  ];

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Firewall - allow SSH by default
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # Journald configuration
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=7d
  '';

  # Time zone
  time.timeZone = "UTC";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable QEMU guest agent for Proxmox
  services.qemuGuest.enable = true;

  # Basic security hardening
  security.sudo.wheelNeedsPassword = true;
  
  # Boot configuration
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
  boot.loader.timeout = 5;

  # Keep failed builds for debugging
  nix.extraOptions = ''
    keep-outputs = true
    keep-derivations = true
  '';

  # Set system state version (don't change after initial install)
  system.stateVersion = "23.11";
}
