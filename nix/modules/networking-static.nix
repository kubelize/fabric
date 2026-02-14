{ config, lib, pkgs, ... }:

with lib;

{
  options.fabric.networking = {
    static = {
      enable = mkEnableOption "static networking configuration";
      
      interface = mkOption {
        type = types.str;
        default = "ens18";
        description = "Primary network interface";
      };
      
      address = mkOption {
        type = types.str;
        description = "Static IP address with CIDR (e.g., 10.0.1.10/24)";
      };
      
      gateway = mkOption {
        type = types.str;
        description = "Default gateway IP";
      };
      
      nameservers = mkOption {
        type = types.listOf types.str;
        default = [ "1.1.1.1" "8.8.8.8" ];
        description = "DNS nameservers";
      };
    };
  };

  config = mkIf config.fabric.networking.static.enable {
    networking = {
      useDHCP = false;
      interfaces.${config.fabric.networking.static.interface} = {
        useDHCP = false;
        ipv4.addresses = [{
          address = builtins.head (builtins.split "/" config.fabric.networking.static.address);
          prefixLength = lib.toInt (builtins.elemAt (builtins.split "/" config.fabric.networking.static.address) 2);
        }];
      };
      defaultGateway = config.fabric.networking.static.gateway;
      nameservers = config.fabric.networking.static.nameservers;
    };

    # Disable systemd-networkd wait-online for faster boots
    systemd.services.systemd-networkd-wait-online.enable = false;
  };
}
