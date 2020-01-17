{ stdenv, fetchFromGitHub, autoreconfHook, apacheHttpd, libmaxminddb }:

stdenv.mkDerivation rec {
  pname = "mod_maxminddb";
  version = "unstable-2019-11-12";

  src = fetchFromGitHub {
    owner = "maxmind";
    repo = "mod_maxminddb";
    rev = "8075dba19d1bf9015ad2eedc295708f25a464a87";
    sha256 = "07rshbwl1bwil1qvh1lz60s377hgpcxwwd6s32nly6xgfnmxqjii";
  };

  nativeBuildInputs = [ autoreconfHook ];
  buildInputs = [ apacheHttpd libmaxminddb ];

  configureFlags = [
    "--with-apxs=${apacheHttpd.dev}/bin/apxs"
  ];

  installPhase = ''
    mkdir -p $out/modules
    cp src/.libs/mod_maxminddb.so $out/modules/
  '';

  meta = with stdenv.lib; {
    homepage = "http://maxmind.github.io/mod_maxminddb/";
    description = "Allows you to query MaxMind DB files from Apache 2.2+ using the libmaxminddb library";
    license = licenses.asl20;
    maintainers = with maintainers; [ aanderse ];
    platforms = platforms.linux;
  };
}
