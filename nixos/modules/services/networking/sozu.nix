{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.sozu;
  format = pkgs.formats.toml {};
  configFile = format.generate "config.toml" cfg.settings;
in
{
  options.services.sozu = {
    enable = mkEnableOption "Sozu server";

    package = mkOption {
      type = types.package;
      default = pkgs.sozu;
      description = "Sozu package to use.";
    };

    settings = mkOption {
      type = format.type;
      default = {};
      description = ''
        Sozu configuration. Refer to
        <link xlink:href="https://github.com/sozu-proxy/sozu/blob/master/doc/configure.md">here</link>.
        for details on supported values.
      '';
    };

  };

  config = mkIf cfg.enable {

    services.sozu.settings = mapAttrs (name: mkDefault) {
      automatic_save_state = false;
      log_level = "info";
      log_target = "stdout";
      command_socket = "/run/sozu/sozu.sock";
      command_buffer_size = 1000000;
      max_command_buffer_size = cfg.command_buffer_size * 2;
      worker_count = 2;
      worker_automatic_restart = true;
      handle_process_affinity = false;
      # current max file descriptor soft limit is: 1024
      # the worker needs two file descriptors per client connection
      max_connections = 1024 / 2;
      max_buffers = 1000;
      buffer_size = 16384;
      ctl_command_timeout = 1000;
      pid_file_path = "/run/sozu/sozu.pid";
      tls_provider = "rustls";
      front_timeout = 60;
      zombie_check_interval = 1800;
      activate_listeners = true;
    };

    environment.etc."sozu/config.toml".source = configFile;

    environment.systemPackages = with pkgs; [
      cfg.package
    ];

    users.groups.sozu = {};
    users.users.sozu = {
      description = "Sozu Daemon User";
      group = "sozu";
      isSystemUser = true;
    };

    systemd.services.sozu = {
      description = "Sozu - A HTTP reverse proxy, configurable at runtime, fast and safe, built in Rust.";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ configFile ];

      serviceConfig = {
        PIDFile = cfg.settings.pid_file_path;
        ExecStart = "${cfg.package}/bin/sozu start --config /etc/sozu/config.toml";
        ExecReload = "${cfg.package}/bin/sozuctl --config /etc/sozu/config.toml reload";
        Restart = "on-failure";
        User = "sozu";
        Group = "sozu";
        RuntimeDirectory = "sozu";
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      };

    };

  };

  meta = with lib; {
    maintainers = with maintainer; [ netcrns ];
  };

}
