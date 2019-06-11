{ stdenv, fetchFromGitHub, cmake, pkgconfig, glib, gpgme, gnutls, hiredis, openldap, libgcrypt, libssh, libuuid }:

stdenv.mkDerivation rec {
  pname = "gvm-libs";
  version = "10.0.0";

  src = fetchFromGitHub {
    owner = "greenbone";
    repo = pname;
    rev = "v${version}";
    sha256 = "161i68830zh0pk3ndjr0jk7zsz123js71fqjd294kklm19d5bhvd";
  };

  prePatch = ''
    sed 's|install (DIRECTORY DESTINATION ''${GVM_PID_DIR})||' -i base/CMakeLists.txt
  '';

  nativeBuildInputs = [ cmake pkgconfig ];
  buildInputs = [ glib gpgme gnutls hiredis openldap libgcrypt libssh libuuid ];

  cmakeFlags = [
    "-DGVM_PID_DIR=/run/gvm"
    "-DLOCALSTATEDIR=/var"
    "-DSYSCONFDIR=/etc"
  ];

  meta = with stdenv.lib; {
    description = "The libraries module for the Greenbone Vulnerability Management Solution";
    homepage = "https://www.greenbone.net/";
    maintainers = [ maintainers.aanderse ];
    platforms = platforms.all;
    license = licenses.gpl2;
  };
}
