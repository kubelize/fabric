{ config, lib, pkgs, ... }:

with lib;

{
  options.fabric.gitops = {
    enable = mkEnableOption "GitOps self-convergence";
    
    flakeRef = mkOption {
      type = types.str;
      description = "Flake reference to pull and apply";
      example = "git+https://github.com/kubelize/fabric#hostname";
    };
    
    autoApply = {
      enable = mkEnableOption "automatic periodic application";
      
      interval = mkOption {
        type = types.str;
        default = "1h";
        description = "How often to check and apply (systemd time format)";
      };
      
      randomizedDelay = mkOption {
        type = types.str;
        default = "10min";
        description = "Random delay to prevent thundering herd";
      };
    };
    
    onBoot = mkOption {
      type = types.bool;
      default = false;
      description = "Apply configuration on boot";
    };
  };

  config = mkIf config.fabric.gitops.enable {
    # One-shot service to apply configuration
    systemd.services.nixos-gitops-apply = {
      description = "Apply NixOS configuration from Git";
      path = with pkgs; [ nixos-rebuild git ];
      
      serviceConfig = {
        Type = "oneshot";
        # Run as root (needed for nixos-rebuild)
        User = "root";
        # Prevent multiple instances
        ExecCondition = "${pkgs.bash}/bin/bash -c '! systemctl is-active nixos-gitops-apply.service'";
      };
      
      script = ''
        set -euo pipefail
        
        echo "Pulling configuration from ${config.fabric.gitops.flakeRef}"
        
        # Apply the configuration
        nixos-rebuild switch --flake "${config.fabric.gitops.flakeRef}" \
          --no-build-output \
          || {
            echo "Failed to apply configuration"
            exit 1
          }
        
        echo "Configuration applied successfully"
      '';
      
      # Start on boot if enabled
      wantedBy = mkIf config.fabric.gitops.onBoot [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    # Timer for periodic application
    systemd.timers.nixos-gitops-apply = mkIf config.fabric.gitops.autoApply.enable {
      description = "Periodic GitOps configuration application";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = config.fabric.gitops.autoApply.interval;
        RandomizedDelaySec = config.fabric.gitops.autoApply.randomizedDelay;
        Persistent = true;
      };
    };

    # Ensure git is available
    environment.systemPackages = with pkgs; [ git ];
    
    # Allow git operations
    networking.firewall.allowedTCPPorts = mkIf config.fabric.gitops.enable [ ];
  };
}
