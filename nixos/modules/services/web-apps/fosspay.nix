{ lib, pkgs, config, ... }:

let
  cfgs = config.services;
  cfg  = cfgs.fosspay;
in
  {
    options.services.fosspay = {
      enable = lib.mkEnableOption "Donation collection for FOSS groups and individuals.";

      configFile = lib.mkOption {
        type = with lib.types; nullOr path;
        default = null;
        example = "./config.ini";
        description = ''
          The path to a configuration file. See <link xlink:href="
          https://git.sr.ht/~sircmpwn/fosspay/blob/master/config.ini.example"/>
        '';
      };

      config = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = ''
          [dev]
          protocol=http
          domain=localhost:5000
        # Change this value to something random and secret
          secret-key=hello world

          smtp-host=mail.example.org
          smtp-port=587
          smtp-user=you
          smtp-password=password
          smtp-from=donate@example.org

          your-name=Joe Bloe
          your-email=joe@example.org

          connection-string=postgresql://postgres@localhost/fosspay

          stripe-secret=
          stripe-publish=

          currency=usd
          default-amounts=3 5 10 20
          default-amount=5
          default-type=monthly
          public-income=yes
          goal=500
        '';
        description = ''
          Content of the config file. See <link xlink:href="
          https://git.sr.ht/~sircmpwn/fosspay/blob/master/config.ini.example"/>
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services.fosspay = let
        customConfig = if (cfg.configFile != null)
        then cfg.configFile
        else cfg.config;
        fosspay = if (customConfig != null)
        then pkgs.fosspay.override { conf=customConfig; }
        else pkgs.fosspay;
      in {
      # after = [ "postgresql.service" ];
      # bindsTo = [ "postgresql.service" ];
      serviceConfig = {
        Type = "simple";
        User = "fosspay";
        Group = "fosspay";
        WorkingDirectory = "${fosspay}/share";
        ExecStart = "${fosspay}/bin/fosspay";
      };
    };

    services.postgresql = {
      enable = true;
      authentication = ''
        local all all trust
        host all all 127.0.0.1/32 trust
        host all all ::1/128 trust
      '';
      ensureDatabases = [ "fosspay" ];
      ensureUsers = [
        {
          name = "fosspay";
          ensurePermissions = { "DATABASE fosspay" = "ALL PRIVILEGES"; };
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
