{ config, lib, pkgs, ... }:

with lib;

{
  options.fabric.docker-host = {
    enable = mkEnableOption "Docker host configuration";
    
    enableCompose = mkOption {
      type = types.bool;
      default = true;
      description = "Install Docker Compose";
    };
    
    storageDriver = mkOption {
      type = types.str;
      default = "overlay2";
      description = "Docker storage driver";
    };
    
    allowedUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional users to add to docker group";
    };
  };

  config = mkIf config.fabric.docker-host.enable {
    virtualisation.docker = {
      enable = true;
      storageDriver = config.fabric.docker-host.storageDriver;
      
      # Auto-prune to save space
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
      
      # Daemon configuration
      daemon.settings = {
        log-driver = "json-file";
        log-opts = {
          max-size = "10m";
          max-file = "3";
        };
      };
    };

    # Install Docker Compose if enabled
    environment.systemPackages = with pkgs; [
      docker
    ] ++ optionals config.fabric.docker-host.enableCompose [
      docker-compose
    ];

    # Add additional users to docker group
    users.users = builtins.listToAttrs (
      map (user: {
        name = user;
        value = {
          extraGroups = [ "docker" ];
        };
      }) config.fabric.docker-host.allowedUsers
    );

    # Open Docker API port if needed (disabled by default for security)
    # networking.firewall.allowedTCPPorts = [ 2375 ];
  };
}
