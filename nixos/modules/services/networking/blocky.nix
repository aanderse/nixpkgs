{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.blocky;

  format = pkgs.formats.yaml {};
  configFile = format.generate "config.yaml" cfg.settings;
in
{
  # interface
  options.services.blocky = {
    enable = mkEnableOption "blocky, a DNS proxy and ad-blocker for the local network written";

    settings = mkOption {
      type = format.type;
      default = {};
      description = ''
        Blocky configuration. Refer to
        <link xlink:href="https://0xerr0r.github.io/blocky/configuration/"/>
        for details on supported values.
      '';
    };
  };

  # implementation
  config = mkIf cfg.enable {
    systemd.services.blocky = {
      description = "A DNS proxy and ad-blocker for the local network";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${pkgs.blocky}/bin/blocky --config ${configFile}";

        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      };
    };
  };
}
