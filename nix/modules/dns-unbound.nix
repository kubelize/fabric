{ config, lib, pkgs, ... }:

with lib;

{
  options.fabric.dns-unbound = {
    enable = mkEnableOption "Unbound DNS server";
    
    listenAddresses = mkOption {
      type = types.listOf types.str;
      default = [ "127.0.0.1" "::1" ];
      description = "Addresses to listen on";
    };
    
    allowedNetworks = mkOption {
      type = types.listOf types.str;
      default = [ "127.0.0.0/8" ];
      description = "Networks allowed to query";
    };
    
    forwardZones = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {};
      example = {
        "example.com" = [ "10.0.1.1" ];
      };
      description = "Zones to forward to specific nameservers";
    };
    
    localZones = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {
        "router.local" = "10.0.1.1";
      };
      description = "Local DNS overrides";
    };
    
    enableDNSSEC = mkOption {
      type = types.bool;
      default = true;
      description = "Enable DNSSEC validation";
    };
  };

  config = mkIf config.fabric.dns-unbound.enable {
    services.unbound = {
      enable = true;
      
      settings = {
        server = {
          interface = config.fabric.dns-unbound.listenAddresses;
          access-control = map (net: "${net} allow") config.fabric.dns-unbound.allowedNetworks;
          
          # Performance tuning
          num-threads = 2;
          msg-cache-slabs = 4;
          rrset-cache-slabs = 4;
          infra-cache-slabs = 4;
          key-cache-slabs = 4;
          
          # Privacy
          hide-identity = true;
          hide-version = true;
          
          # DNSSEC
          auto-trust-anchor-file = mkIf config.fabric.dns-unbound.enableDNSSEC 
            "/var/lib/unbound/root.key";
          module-config = mkIf config.fabric.dns-unbound.enableDNSSEC 
            "\"validator iterator\"";
          
          # Local data
          local-data = mapAttrsToList 
            (name: addr: "\"${name}. A ${addr}\"") 
            config.fabric.dns-unbound.localZones;
        };
        
        # Forward zones
        forward-zone = mapAttrsToList
          (zone: servers: {
            name = zone;
            forward-addr = servers;
          })
          config.fabric.dns-unbound.forwardZones;
      };
    };

    # Open DNS ports
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    # Additional tools for DNS troubleshooting
    environment.systemPackages = with pkgs; [
      bind # for dig, nslookup
      drill # alternative DNS tool
    ];
  };
}
