{ config, pkgs, ... }:

{
  # Hostname
  networking.hostName = "test-vm";
  
  # Generate a unique host ID
  networking.hostId = "4f8a1c6d";

  # Use DHCP for testing
  networking.useDHCP = true;
  networking.interfaces.ens18.useDHCP = true;

  # Minimal configuration - just the basics
  # The base module provides SSH, firewall, and essential tools

  # Create admin user
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... admin@homelab"
    ];
  };

  # Optional: Enable monitoring
  # fabric.monitoring.nodeExporter = {
  #   enable = true;
  #   openFirewall = true;
  # };

  # GitOps self-convergence (disabled by default for test VMs)
  # fabric.gitops = {
  #   enable = true;
  #   flakeRef = "git+https://github.com/kubelize/fabric?ref=main#test-vm";
  # };
}
