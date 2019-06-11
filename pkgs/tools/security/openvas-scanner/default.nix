{ stdenv, fetchFromGitHub, cmake, pkgconfig, bison, flex, glib, gpgme, gnutls, gvm-libs, redis, libgcrypt, libksba, libpcap, libssh }:

stdenv.mkDerivation rec {
  pname = "openvas-scanner";
  version = "6.0.0";

  src = fetchFromGitHub {
    owner = "greenbone";
    repo = pname;
    rev = "v${version}";
    sha256 = "0pch3hyqrccc7hvh1hw5q5yr7mah2vafl7bp9hygizm0wg61zlkc";
  };

  nativeBuildInputs = [ cmake pkgconfig bison flex ];
  buildInputs = [ glib gnutls gpgme gvm-libs redis libgcrypt libksba libpcap libssh  ];

  meta = with stdenv.lib; {
    description = "A remote network security scanner";
    homepage = "https://www.greenbone.net/";
    maintainers = [ maintainers.aanderse ];
    platforms = platforms.all;
    license = with licenses; [ gpl2 gpl2Plus ];
  };
}
