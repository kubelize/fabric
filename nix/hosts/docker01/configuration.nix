{ config, pkgs, ... }:

{
  # Hostname
  networking.hostName = "docker01";
  
  # Generate a unique host ID
  networking.hostId = "7b3d9f2a";

  # Static networking configuration
  fabric.networking.static = {
    enable = true;
    interface = "ens18";
    address = "10.0.1.20/24";
    gateway = "10.0.1.1";
    nameservers = [
      "10.0.1.10"  # Use our DNS server
      "1.1.1.1"
    ];
  };

  # Docker host configuration
  fabric.docker-host = {
    enable = true;
    enableCompose = true;
    storageDriver = "overlay2";
    allowedUsers = [ "admin" ];
  };

  # Enable monitoring
  fabric.monitoring.nodeExporter = {
    enable = true;
    openFirewall = true;
  };

  # GitOps self-convergence (optional)
  fabric.gitops = {
    enable = false;  # Set to true once VM is provisioned
    flakeRef = "git+https://github.com/kubelize/fabric?ref=main#docker01";
    autoApply = {
      enable = false;
      interval = "1h";
    };
    onBoot = false;
  };

  # Create admin user
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... admin@homelab"
    ];
  };

  # Additional Docker-related packages
  environment.systemPackages = with pkgs; [
    docker-compose
    dive  # Docker image explorer
    ctop  # Container metrics
  ];

  # Optional: Enable Docker metrics for Prometheus
  # virtualisation.docker.daemon.settings = {
  #   metrics-addr = "0.0.0.0:9323";
  #   experimental = true;
  # };
  # networking.firewall.allowedTCPPorts = [ 9323 ];
}
