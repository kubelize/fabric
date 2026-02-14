{ config, lib, pkgs, ... }:

with lib;

{
  options.fabric.monitoring = {
    nodeExporter = {
      enable = mkEnableOption "Prometheus Node Exporter";
      
      port = mkOption {
        type = types.int;
        default = 9100;
        description = "Port for node exporter";
      };
      
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open firewall for node exporter";
      };
    };
  };

  config = mkMerge [
    # Node Exporter
    (mkIf config.fabric.monitoring.nodeExporter.enable {
      services.prometheus.exporters.node = {
        enable = true;
        port = config.fabric.monitoring.nodeExporter.port;
        enabledCollectors = [
          "systemd"
          "processes"
          "cpu"
          "diskstats"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "netstat"
          "stat"
          "time"
          "vmstat"
        ];
      };

      networking.firewall.allowedTCPPorts = mkIf config.fabric.monitoring.nodeExporter.openFirewall 
        [ config.fabric.monitoring.nodeExporter.port ];
    })
  ];
}
