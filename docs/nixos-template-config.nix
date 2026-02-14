# /etc/nixos/configuration.nix
# Minimal NixOS configuration for Proxmox template
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot loader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # Enable QEMU guest agent
  services.qemu-guest-agent.enable = true;

  # Cloud-init support (optional but recommended)
  services.cloud-init = {
    enable = true;
    network.enable = true;
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Allow root SSH with key (for initial setup)
  users.users.root.openssh.authorizedKeys.keys = [
    # Add your SSH public key here temporarily
    # "ssh-ed25519 AAAA... your-key"
  ];

  # Networking (will be overridden by cloud-init if enabled)
  networking = {
    useDHCP = true;
    hostName = "nixos-template";
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    qemu-utils
  ];

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Clean up on shutdown to reduce template size
  boot.tmp.cleanOnBoot = true;

  system.stateVersion = "24.05";
}
