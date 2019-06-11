{ stdenv, fetchFromGitHub, cmake, pkgconfig, makeWrapper, glib, gnutls, gpgme, gvm-libs, sqlite, postgresql, libical }:

stdenv.mkDerivation rec {
  pname = "gvmd";
  version = "8.0.0";

  src = fetchFromGitHub {
    owner = "greenbone";
    repo = pname;
    rev = "v${version}";
    sha256 = "0kiwcvzdpx246q67a4shs9jc4misvnmpqwsmmvidn705cbvgickx";
  };

  prePatch = ''
    sed 's|install (DIRECTORY DESTINATION ''${GVMD_STATE_DIR})||' -i CMakeLists.txt
    sed 's|DESTINATION ''${GVM_SYSCONF_DIR})|DESTINATION ${placeholder "out"}/etc)|' -i CMakeLists.txt
  '';

  nativeBuildInputs = [ cmake pkgconfig makeWrapper ];
  buildInputs = [ glib gnutls gpgme gvm-libs sqlite postgresql libical ];

  cmakeFlags = [
    "-DGVM_RUN_DIR=/run/gvm"
    "-DLOCALSTATEDIR=/var"
    "-DSYSCONFDIR=/etc"
  ];

  postFixup = ''
    wrapProgram $out/bin/gvm-manage-certs \
      --prefix PATH : ${gnutls}/bin
  '';

  meta = with stdenv.lib; {
    description = "Greenbone Vulnerability Manager";
    homepage = "https://www.greenbone.net/";
    maintainers = [ maintainers.aanderse ];
    platforms = platforms.all;
    license = licenses.gpl2;
  };
}
