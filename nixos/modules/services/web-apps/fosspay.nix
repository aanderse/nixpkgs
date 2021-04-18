{ config, pkgs, lib, ... }:

let
  cfg = config.services.fosspay;

  package = pkgs.fosspay.override { conf = "${stateDir}/config.ini"; };
  format = pkgs.formats.ini {};
  stateDir = "/var/lib/fosspay";
  configFile = format.generate "config.ini" cfg.settings;
in
{
  options.services.fosspay = {
    enable = lib.mkEnableOption "Donation collection for FOSS groups and individuals.";

    secretKeyFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/keys/fosspay-secret-key";
      description = ''
        A file containing a key for use with fosspay.
      '';
    };

    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Database host address.";
      };

      port = mkOption {
        type = types.int;
        default = 5432;
        description = "Database host port.";
      };

      name = mkOption {
        type = types.str;
        default = "fosspay";
        description = "Database name.";
      };

      user = mkOption {
        type = types.str;
        default = "fosspay";
        description = "Database user.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/keys/fosspay-dbpassword";
        description = ''
          A file containing the password corresponding to
          <option>database.user</option>.
        '';
      };

      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Create the database and database user locally.";
      };
    };

    settings = lib.mkOption {
      type = format.type;
      default = {};
      example = literalExample ''
        dev = {
          protocol = "http";
          domain = "localhost:5000";

          your-name = "Joe Bloe";
          your-email = "joe@example.org";

          currency = "usd";
          default-amounts = "3 5 10 20";
          default-amount = 5;
          default-type = "monthly";
          public-income = true;
          goal = 500;
        };
      '';
      description = ''
        fosspay configuration. Refer to
        <link xlink:href="https://git.sr.ht/~sircmpwn/fosspay/blob/master/config.ini.example"/>
        for details on supported values.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.fosspay = {
      description = "fosspay website";
      wantedBy = [ "multi-user.target" ];
      # after = lib.optionals cfg.database.createLocally [ "postgresql.service" ];
      # bindsTo = lib.optionals cfg.database.createLocally [ "postgresql.service" ];

      preStart = ''
        cp -f ${configFile} ${stateDir}/config.ini

        # insert our secret files into config.ini that we'll use
        ${pkgs.crudini}/bin/crudini --set ${stateDir}/config.ini dev secret-key "$(head -n1 ${cfg.secretKeyFile})"
        # ${pkgs.crudini}/bin/crudini --set ${stateDir}/config.ini dev smtp-password "$(head -n1 ${cfg.smtp.passwordFile})"
        # if cfg.database.createLocally != true ... -> ${pkgs.crudini}/bin/crudini --set ${stateDir}/config.ini dev connection-string "postgresql://${cfg.database.user}@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}" and "$(head -n1 ${cfg.database.passwordFile})"
        # etc...
      '';
      serviceConfig = {
        User = "fosspay";
        Group = "fosspay";
        StateDirectory = "fosspay";
        StateDirectoryMode = "0700";
        WorkingDirectory = "${package}/share";
        ExecStart = "${package}/bin/fosspay";
      };
    };

    services.postgresql = lib.optionalAttrs cfg.database.createLocally {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensurePermissions = { "DATABASE ${cfg.database.name}" = "ALL PRIVILEGES"; };
        }
      ];
    };

    users.users = {
      fosspay = {
        isSystemUser = true;
        group = "fosspay";
      };
    };

    users.groups = {
      fosspay = {};
    };
  };
}
