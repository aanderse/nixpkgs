{ config, lib, pkgs, utils, ... }:

let
  inherit (lib) mkDefault mkEnableOption mkIf mkOption optionalAttrs optionals types;

  cfg = config.services.flarum;

  # custom variant of https://github.com/flarum/flarum/blob/master/site.php
  customSite = pkgs.writeText "site.php" ''
    <?php

    require '${pkgs.flarum.dependencies}/vendor/autoload.php';

    return Flarum\Foundation\Site::fromPaths([
        'base' => '${cfg.stateDir}',
        'public' => '${cfg.stateDir}/public',
        'storage' => '${cfg.stateDir}/storage',
        'vendor' => '${pkgs.flarum.dependencies}/vendor',
    ]);
  '';

  defaultInstallConfig = lib.generators.toYAML {} {
    debug = false;
    baseUrl = "https://${cfg.domain}";
    databaseConfiguration = {
      driver = "mysql";
      host = "localhost";
      database = "flarum";
      username = "flarum";
    };
    adminUser = {
      username = "admin";
      password = "correcthorsebatterystaple";
      email = "admin@example.net";
    };
  };

  flarum-cli = pkgs.writeScriptBin "flarum" ''
    #! ${pkgs.runtimeShell}
    cd ${cfg.stateDir}
    sudo=exec
    if [[ "$USER" != ${cfg.user} ]]; then
      sudo='exec /run/wrappers/bin/sudo -u ${cfg.user}'
    fi
    $sudo ${pkgs.php}/bin/php flarum "$@"
  '';
in {
  options = {
    services.flarum = {
      enable = mkEnableOption "Flarum discussion platform";

      domain = mkOption {
        type = types.str;
        default = "localhost";
        example = "forum.example.com";
        description = "Domain to serve on.";
      };

      user = mkOption {
        type = types.str;
        default = "flarum";
        description = "System user to run Flarum";
      };

      group = mkOption {
        type = types.str;
        default = "flarum";
        description = "System group to run Flarum";
      };

      stateDir = mkOption {
        type = types.path;
        default = "/var/lib/flarum";
        description = "Home directory for writable storage";
      };

      database = {
        createLocally = mkOption {
          type = types.bool;
          default = true;
          description = ''
            If set to true this option will:
            - install and configure a MariaDB database on this server
            - create a database called "flarum" locally
            - create a database user called ''${services.flarum.user} locally
            - grant permissions on the flarum database to the locally created user
          '';
        };
      };

      installConfig = mkOption {
        type = types.path;
        description = ''
          Initial installation configuration to provide Flarum.
          https://discuss.flarum.org/d/22187-command-line-install-via-php-flarum-install-no-interaction
        '';
        default = pkgs.writeText "config.yml" defaultInstallConfig;
        defaultText = defaultInstallConfig;
      };

      poolConfig = mkOption {
        type = with types; attrsOf (oneOf [ str int bool ]);
        default = {
          "pm" = "dynamic";
          "pm.max_children" = 10;
          "pm.start_servers" = 2;
          "pm.min_spare_servers" = 1;
          "pm.max_spare_servers" = 3;
          "pm.max_requests" = 500;
        };
        description = ''
          Options for the Flarum PHP pool. See the documentation on <literal>php-fpm.conf</literal>
          for details on configuration directives.
        '';
      };
    };
  };

  config = mkIf cfg.enable {

    # allow the sysadmin to manage database migrations, etc...
    environment.systemPackages = [ flarum-cli ];

    services.phpfpm.pools.flarum = {
      inherit (cfg) user group;
      settings = {
        "listen.owner" = config.services.httpd.user;
        "listen.group" = config.services.httpd.group;
        "listen.mode" = "0600";
      } // cfg.poolConfig;
    };

    # TODO: enable nginx configuration
#    services.nginx = {
#      enable = true;
#      virtualHosts."${cfg.domain}" = {
#        root = "${cfg.stateDir}/public";
#        locations."~ \.php$".extraConfig =
#          ''
#          fastcgi_pass unix:${config.services.phpfpm.pools.flarum.socket};
#          fastcgi_index site.php;
#          '';
#        extraConfig =
#          ''
#          index index.php;
#          include ${pkgs.flarum.src}/.nginx.conf;
#          '';
#      };
#    };

    # TODO: delete httpd configuration
    services.httpd.enable = true;
    services.httpd.extraModules = [ "proxy_fcgi" ];
    services.httpd.virtualHosts.${cfg.domain} = {
      documentRoot = "${cfg.stateDir}/public";
      extraConfig = ''
        <Directory ${cfg.stateDir}/public>
          AllowOverride all
          DirectoryIndex index.php
          Require all granted
          Options FollowSymLinks

          <FilesMatch "\.php$">
            <If "-f %{REQUEST_FILENAME}">
              SetHandler "proxy:unix:${config.services.phpfpm.pools.flarum.socket}|fcgi://localhost/"
            </If>
          </FilesMatch>
        </Directory>
      '';
    };

    services.mysql = mkIf cfg.database.createLocally {
      enable = true;
      package = mkDefault pkgs.mariadb;
      ensureDatabases = [ "flarum" ];
      ensureUsers = [
        { name = cfg.user;
          ensurePermissions = {
            "flarum.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    systemd.tmpfiles.rules = [
      # create the required directory structure
      "d '${cfg.stateDir}' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/public' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/public/assets' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/storage' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/storage/cache' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/storage/formatter' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/storage/less' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/storage/locale' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/storage/logs' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/storage/sessions' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/storage/tmp' - ${cfg.user} ${cfg.user}"
      "d '${cfg.stateDir}/storage/views' - ${cfg.user} ${cfg.user}"

      # unfortunately these few files must exist in a mutable directory
      "L+ '${cfg.stateDir}/flarum' - - - - ${pkgs.flarum.src}/flarum"
      "L+ '${cfg.stateDir}/site.php' - - - - ${customSite}"
      "L+ '${cfg.stateDir}/public/.htaccess' - - - - ${pkgs.flarum.src}/public/.htaccess"
      "L+ '${cfg.stateDir}/public/index.php' - - - - ${pkgs.flarum.src}/public/index.php"

      # allow the sysadmin to customize flarum
      "C '${cfg.stateDir}/extend.php' - - - - ${pkgs.flarum.src}/extend.php"

      # ensure ownership if cfg.user or cfg.group has changed
      "Z '${cfg.stateDir}' - ${cfg.user} ${cfg.user}"
    ];

    systemd.services.flarum-install = {
      description = "Flarum installation";
      after = optionals cfg.database.createLocally [ "mysql.service" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
        ${pkgs.php}/bin/php flarum install --file=${cfg.installConfig}
        ${pkgs.php}/bin/php flarum migrate
      '';

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
      };

      unitConfig = {
        ConditionPathExists = "!${cfg.stateDir}/config.php";
      };
    };

    users.users = optionalAttrs (cfg.user == "flarum") {
      flarum = {
        isSystemUser = true;
        home = cfg.stateDir;
        group = cfg.group;
      };
    };

    users.groups = optionalAttrs (cfg.group == "flarum") {
      flarum = {};
    };
  };
}
