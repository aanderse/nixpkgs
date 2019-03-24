import ./make-test.nix ({ pkgs, ... }: {
  name = "minidlna";

  nodes = {
    server =
      { ... }:
      {
        imports = [ ../modules/profiles/minimal.nix ];
        networking.firewall.allowedTCPPorts = [ 8200 ];
        services.minidlna = {
          enable = true;
          mediaDirs = [
           "PV,/tmp/stuff"
          ];
          config = {
            friendly_name = "rpi3";
            log_level = "error";
            root_container = "B";
            notify_interval = 60;
            album_art_names = [
              "Cover.jpg/cover.jpg/AlbumArtSmall.jpg/albumartsmall.jpg"
              "AlbumArt.jpg/albumart.jpg/Album.jpg/album.jpg"
              "Folder.jpg/folder.jpg/Thumb.jpg/thumb.jpg"
            ];
          };
        };
      };
      client = { ... }: { };
  };

  testScript =
  ''
    startAll;
    $server->succeed("mkdir -p /tmp/stuff && chown minidlna: /tmp/stuff");
    $server->waitForUnit("minidlna");
    $server->waitForOpenPort("8200");
    $server->succeed("curl --fail http://localhost:8200/");
    $client->succeed("curl --fail http://server:8200/");
  '';
})
