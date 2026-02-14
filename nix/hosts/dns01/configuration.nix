{ config, pkgs, ... }:

{
  # Hostname
  networking.hostName = "dns01";
  
  # Generate a unique host ID for ZFS if needed
  # Run: head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n'
  networking.hostId = "8425e349";

  # Static networking configuration
  fabric.networking.static = {
    enable = true;
    interface = "ens18";
    address = "10.0.1.10/24";
    gateway = "10.0.1.1";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
  };

  # DNS server configuration
  fabric.dns-unbound = {
    enable = true;
    listenAddresses = [ "0.0.0.0" "::0" ];
    allowedNetworks = [
      "127.0.0.0/8"
      "10.0.0.0/8"      # Adjust to your network
      "192.168.0.0/16"  # Adjust to your network
    ];
    
    # Example: forward internal zone to another DNS
    forwardZones = {
      # "internal.example.com" = [ "10.0.1.5" ];
    };
    
    # Example: local host overrides
    localZones = {
      "router.local" = "10.0.1.1";
      "nas.local" = "10.0.1.5";
    };
    
    enableDNSSEC = true;
  };

  # Enable monitoring
  fabric.monitoring.nodeExporter = {
    enable = true;
    openFirewall = true;
  };

  # GitOps self-convergence (optional - enable after initial setup)
  fabric.gitops = {
    enable = false;  # Set to true once VM is provisioned
    flakeRef = "git+https://github.com/kubelize/fabric?ref=main#dns01";
    autoApply = {
      enable = false;  # Enable after testing
      interval = "1h";
    };
    onBoot = false;
  };

  # Create admin user
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... admin@homelab"
    ];
  };
}
