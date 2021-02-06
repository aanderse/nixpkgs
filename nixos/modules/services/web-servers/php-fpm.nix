{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.php-fpm;
  runtimeDir = "/run/php-fpm";

  poolOpts =
    { name, ... }:
    {
      freeformType = with types; attrsOf (oneOf [ str int bool ]);

      options = {
        package = mkOption {
          type = types.package;
          default = pkgs.php;
          defaultText = "pkgs.php";
          description = ''
            The PHP package to use for running this PHP-FPM pool.
          '';
          example = literalExample ''
            pkgs.php80.pkgs.withExtensions ({ enabled, all }: enabled ++ [ all.pspell ]);
          '';
        };

        listen = mkOption {
          type = with types; either port str;
          default = "${runtimeDir}/${name}/${name}.sock";
          description = ''
            The address on which to accept FastCGI requests. Valid syntaxes are:
            <literal>ip.add.re.ss:port</literal>, <literal>port</literal>, and
            <literal>/path/to/unix/socket</literal>.

            <note>
              <para>
                By default each PHP-FPM pool will run with a separate master process. For improved
                security each master process will run as the user specified by the <option>user</option>
                option, instead of <literal>root</literal>. There are several implications to this, the
                most relevant being that when listening on a unix socket (the default behavior) the
                sysadmin must configure groups such that the consumer of this listening socket (the
                <literal>nginx</literal> group, for example) has permissions to access the socket. Therefore
                you should add something like this to your configuration:

                <programlisting>
                  # if using the nginx web server with this php-fpm pool
                  users.users.${config.services.nginx.user}.extraGroups = [ config.services.php-fpm.pools.&lt;name&gt;.group ];

                  # if using the httpd web server with this php-fpm pool
                  users.users.${config.services.httpd.user}.extraGroups = [ config.services.php-fpm.pools.&lt;name&gt;.group ];
                </programlisting>
              </para>
            </note>
          '';
          example = 9000;
        };

        user = mkOption {
          type = types.str;
          description = ''
            User account under which this pool runs.

            If you require the PHP-FPM master process to run as
            <literal>root</literal> add the following configuration:
            <programlisting>
            systemd.services.php-fpm-&lt;name&gt;.serviceConfig.User = lib.mkForce "root";
            </programlisting>
          '';
        };

        group = mkOption {
          type = types.str;
          description = ''
            Group account under which this pool runs.
          '';
        };

        pm = mkOption {
          type = types.enum [ "dynamic" "ondemand" "static" ];
          description = ''
            Choose how the process manager will control the number of child processes.
          '';
        };

        "pm.max_children" = mkOption {
          type = types.int;
          description = ''
            The number of child processes to be created when <option>pm</option> is set to <literal>static</literal> and
            the maximum number of child processes to be created when <option>pm</option> is set to <literal>dynamic</literal>.
          '';
        };
      };
    };
in
{
  # interface
  options.services.php-fpm = {
    settings = mkOption {
      type = with types; attrsOf (oneOf [ str int bool ]);
      default = {};
      description = ''
        PHP-FPM global directives. Refer to the "List of global php-fpm.conf directives" section of
        <link xlink:href="https://www.php.net/manual/en/install.fpm.configuration.php"/>
        for details. Note that settings names must be enclosed in quotes (e.g.
        <literal>"process.priority"</literal> instead of <literal>process.priority</literal>).
      '';
      example = literalExample ''
        {
          "systemd_interval" = 12;
        }
      '';
    };

    pools = mkOption {
      type = with types; attrsOf (submodule poolOpts);
      default = {};
      description = ''
        PHP-FPM configuration. Refer to the "List of pool directives" section of
        <link xlink:href="https://www.php.net/manual/en/install.fpm.configuration.php"/>
        for details on supported values. Note that settings names must be enclosed in quotes (e.g.
        <literal>"pm.max_children"</literal> instead of <literal>pm.max_children</literal>).

        In addition to the configuration mentioned in the above linked "List of pool directives", NixOS
        supports an additional <option>package</option> option where the sysadmin may specify the
        PHP package to use.
      '';
      example = literalExample ''
        {
          nextcloud = {
            "package" = pkgs.php74.buildEnv {
              extensions = { enabled, all }: with all; enabled ++ [ apcu imagick memcached redis ];
              extraConfig = '''
                memory_limit = 512M
                post_max_size = 512M
                upload_max_filesize = 512M
              ''';
            };
            "user" = "nextcloud";
            "group" = "nextcloud";
            "pm" = "dynamic";
            "pm.max_children" = 32;
            "pm.start_servers" = 2;
            "pm.min_spare_servers" = 2;
            "pm.max_spare_servers" = 4;
            "pm.max_requests" = 500;
            "env[PATH]" = "/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin:/bin";
          };

          matomo = {
            "pm" = "dynamic";
            "pm.max_children" = 75;
            "pm.start_servers" = 10;
            "pm.min_spare_servers" = 5;
            "pm.max_spare_servers" = 20;
            "pm.max_requests" = 500;
            "catch_workers_output" = true;
            "env[PIWIK_USER_PATH]" = "/var/lib/matomo";
          };

          devbox = {
            "package" = pkgs.php80;
            "user" = "eelco";
            "group" = "users";
            "pm" = "ondemand";
            "pm.max_children" = 5;
            "pm.process_idle_timeout" = "10s";
            "pm.max_requests" = 200;
            "php_admin_value[memory_limit]" = "32M";
          };
        }
      '';
    };
  };

  # implementation
  config = mkIf (cfg.pools != {}) {

    assertions = [
      { assertion = ! hasAttr "global" cfg.pools;
        message = ''
          A PHP-FPM pool may not be named `global`.
        '';
      }
    ];

    services.php-fpm.settings = {
      daemonize = false;
      error_log = "syslog";
    };

    systemd.tmpfiles.rules = [
      "d ${runtimeDir}"
    ];

    systemd.slices.php-fpm = {
      description = "PHP FastCGI Process manager pools slice";
    };

    systemd.targets.php-fpm = {
      description = "PHP FastCGI Process manager pools target";
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services = mapAttrs' (name: poolOpts:
      let
        extraAttrs = [ "package" ];
        configFile = (pkgs.formats.ini {}).generate "php-fpm.conf" ({ global = cfg.settings; } // { "${name}" = removeAttrs poolOpts extraAttrs; });
      in
      nameValuePair "php-fpm-${name}" {
        description = "PHP-FPM process manager to manage ${name}";
        after = [ "network.target" ];
        wantedBy = [ "php-fpm.target" ];
        partOf = [ "php-fpm.target" ];

        serviceConfig = {
          Type = "notify";
          User = poolOpts.user;
          Group = poolOpts.group;
          ExecStart = "${poolOpts.package}/bin/php-fpm --fpm-config ${configFile}";
          ExecReload = "${pkgs.coreutils}/bin/kill -USR2 $MAINPID";
          Restart = "always";

          PrivateDevices = true;
          PrivateTmp = true;
          ProtectSystem = "full";
          ProtectHome = true;
          # XXX: We need AF_NETLINK to make the sendmail SUID binary from postfix work
          RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";

          RuntimeDirectory = mkIf (poolOpts.listen == "${runtimeDir}/${name}/${name}.sock") "php-fpm/${name}";
        };
      }
    ) cfg.pools;
  };
}
