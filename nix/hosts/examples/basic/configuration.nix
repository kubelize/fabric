{ config, pkgs, ... }:

{
  # Hostname - CHANGE THIS
  networking.hostName = "my-host";
  
  # Generate unique host ID: head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n'
  networking.hostId = "00000000";  # CHANGE THIS

  # Option 1: Static networking
  fabric.networking.static = {
    enable = true;
    interface = "ens18";
    address = "10.0.1.X/24";  # CHANGE THIS
    gateway = "10.0.1.1";
    nameservers = [ "10.0.1.10" "1.1.1.1" ];
  };

  # Option 2: DHCP (comment out static config above if using DHCP)
  # networking.useDHCP = true;
  # networking.interfaces.ens18.useDHCP = true;

  # Enable features as needed:
  
  # Docker host
  # fabric.docker-host = {
  #   enable = true;
  #   enableCompose = true;
  #   allowedUsers = [ "admin" ];
  # };
  
  # DNS server
  # fabric.dns-unbound = {
  #   enable = true;
  #   listenAddresses = [ "0.0.0.0" ];
  #   allowedNetworks = [ "127.0.0.0/8" "10.0.0.0/8" ];
  # };
  
  # Monitoring
  # fabric.monitoring.nodeExporter = {
  #   enable = true;
  #   openFirewall = true;
  # };

  # GitOps self-convergence
  # fabric.gitops = {
  #   enable = true;
  #   flakeRef = "git+https://github.com/kubelize/fabric?ref=main#my-host";
  #   autoApply.enable = false;  # Enable after testing
  # };

  # Create admin user
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3... your-key-here"  # CHANGE THIS
    ];
  };

  # Additional system packages
  # environment.systemPackages = with pkgs; [
  #   vim
  #   tmux
  # ];

  # Additional services, firewall rules, etc.
}
