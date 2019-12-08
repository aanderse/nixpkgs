{ stdenv, lib, fetchurl, go, pkgconfig
, libiconv, openssl, pcre, zlib
, enableAgent2 ? false
}:

import ./versions.nix ({ version, sha256 }:
  stdenv.mkDerivation {
    pname = "zabbix-agent";
    inherit version;

    src = fetchurl {
      url = "mirror://sourceforge/zabbix/ZABBIX%20Latest%20Stable/${version}/zabbix-${version}.tar.gz";
      inherit sha256;
    };

    nativeBuildInputs = [ pkgconfig ] ++ lib.optionals enableAgent2 [ go ];
    buildInputs = [
      libiconv
      openssl
      pcre
    ] ++ lib.optionals enableAgent2 [ zlib ];

    HOME = ".";

    configureFlags = [
      (if enableAgent2 then "--enable-agent2" else "--enable-agent")
      "--with-iconv"
      "--with-libpcre"
      "--with-openssl=${openssl.dev}"
    ];

    postInstall = ''
      cp conf/zabbix_agentd/*.conf $out/etc/zabbix_agentd.conf.d/
    '';

    meta = with stdenv.lib; {
      description = "An enterprise-class open source distributed monitoring solution (client-side agent)";
      homepage = "https://www.zabbix.com/";
      license = licenses.gpl2;
      maintainers = with maintainers; [ mmahut psyanticy ];
      platforms = platforms.linux;
    };
  })
