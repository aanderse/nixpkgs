{ pkgs, stdenv, buildEnv, fetchFromGitHub, cmake, pkgconfig, nodejs, glib, gnutls, gvm-libs, libgcrypt, libmicrohttpd, libxml2 }:

let

  nodePackages = import ./node.nix {
    inherit pkgs;
    inherit (stdenv.hostPlatform) system;
  };

  nodeEnv = buildEnv {
    name = "gsa-runtime";
    paths = with nodePackages; [
      nodePackages."@vx/axis-^0.0.183"
      nodePackages."@vx/gradient-^0.0.183"
      nodePackages."@vx/shape-^0.0.179"
      nodePackages."core-js-^2.6.5"
      nodePackages."d3-cloud-^1.2.5"
      nodePackages."d3-color-^1.2.3"
      nodePackages."d3-force-^2.0.0"
      nodePackages."d3-format-^1.3.2"
      nodePackages."d3-hierarchy-^1.1.8"
      nodePackages."d3-interpolate-^1.3.2"
      nodePackages."d3-scale-^2.1.2"
      nodePackages."d3-shape-^1.3.3"
      nodePackages."downshift-^1.31.16"
      nodePackages."fast-deep-equal-^1.1.0"
      nodePackages."fast-xml-parser-^3.12.13"
      nodePackages."glamor-^2.20.40"
      nodePackages."history-^4.7.2"
      nodePackages."hoist-non-react-statics-^3.3.0"
      nodePackages."i18next-^14.0.1"
      nodePackages."i18next-xhr-backend-1.5.1"
      nodePackages."ical.js-^1.3.0"
      nodePackages."memoize-one-^5.0.0"
      nodePackages."moment-^2.24.0"
      nodePackages."moment-timezone-^0.5.23"
      nodePackages."prop-types-^15.6.2"
      nodePackages."qhistory-^1.0.3"
      nodePackages."qs-^6.6.0"
      nodePackages."react-^16.7.0"
      nodePackages."react-beautiful-dnd-^7.1.3"
      nodePackages."react-datepicker-^1.8.0"
      nodePackages."react-dom-^16.7.0"
      nodePackages."react-redux-^6.0.0"
      nodePackages."react-router-dom-^4.3.1"
      nodePackages."react-scripts-2.1.8"
      nodePackages."redux-^4.0.1"
      nodePackages."redux-logger-^3.0.6"
      nodePackages."redux-thunk-^2.3.0"
      nodePackages."styled-components-^3.4.10"
      nodePackages."uuid-^3.3.2"
      nodePackages."whatwg-fetch-^3.0.0"
      nodePackages."x2js-^3.2.6"
    ];
  };

in
stdenv.mkDerivation rec {
  pname = "gsa";
  version = "8.0.0";

  src = fetchFromGitHub {
    owner = "greenbone";
    repo = pname;
    rev = "v${version}";
    sha256 = "0pckg0aml66b9nas9ykyh6s9qlf18kzglwwkyvzqwb62pna5gn20";
  };

  prePatch = ''
    sed 's|DESTINATION ''${GSAD_CONFIG_DIR})|DESTINATION ${placeholder "out"}/etc)|' -i gsad/CMakeLists.txt
  '';

  #cmakeFlags = [  ];
  cmakeFlags = [
    "-DSKIP_GSA=ON" # tells cmake to skip building the web stuff
    "-DGVM_RUN_DIR=/run/gvm"
    "-DGSAD_PID_DIR=/run/gsad"
    "-DLOCALSTATEDIR=/var"
    "-DSYSCONFDIR=/etc"
  ];

  nativeBuildInputs = [ cmake pkgconfig ];
  buildInputs = [ glib gnutls gvm-libs libgcrypt libmicrohttpd libxml2 ];

  postInstall = ''
    mkdir -p $out/share/gvm/gsad
    # i guess here is where i would build the web stuff...
    # cp -r ../gsa/src/* $out/share/gvm/gsad/
    # cp -r ../gsa/public/* $out/share/gvm/gsad/web/
  '';

  meta = with stdenv.lib; {
    description = "A remote network security scanner";
    homepage = "https://www.greenbone.net/";
    maintainers = [ maintainers.aanderse ];
    platforms = platforms.all;
    license = with licenses; [ gpl2 gpl2Plus ];
  };
}
