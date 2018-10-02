{ stdenv, requireFile, unzip, makeWrapper, oraclejdk, libaio }:

stdenv.mkDerivation rec {
  name = "mod_weblogic-${version}";
  version = "12.2.1.3.0";

  src = requireFile {
    name = "fmw_${version}_wlsplugins_Disk1_1of1.zip";
    url = "https://www.oracle.com/technetwork/middleware/webtier/downloads/index-jsp-156711.html";
    sha256 = "ab15cd89eb0419cad64494dbcd9f706b77aacbe6245e6786199b6e088c9f556f";
  };

  dontBuild = true;

  nativeBuildInputs = [ makeWrapper unzip ];

  unpackPhase = ''
    unzip $src
    unzip WLSPlugins12c-${version}.zip
    unzip WLSPlugin${version}-Apache2.2-Apache2.4-Linux_x86_64-${version}.zip
  '';

  installPhase = ''
    mkdir -p "$out/"{bin,jlib,lib,modules}
    install -Dm755 bin/orapki $out/bin
    install -Dm644 lib/* $out/lib
    install -Dm644 jlib/* $out/jlib

    ln -s $out/lib/mod_wl_24.so $out/modules
  '';

  postFixup = ''
    wrapProgram $out/bin/orapki --set JAVA_HOME ${oraclejdk}

    for f in libclntshcore.so libclntshcore.so.12.1 libclntsh.so libclntsh.so.12.1 libdms2.so libipc1.so libmql1.so libons.so libonsssl.so libonssys.so mod_wl_24.so mod_wl.so; do
      patchelf --set-rpath "${stdenv.lib.makeLibraryPath [ stdenv.cc.cc.lib libaio ]}:$out/lib" $out/lib/$f
    done

    # including stdenv.cc.cc.lib and libaio in the rpath here caused errors
    patchelf --set-rpath $out/lib $out/lib/libnnz12.so
  '';

  meta = with stdenv.lib; {
    description = "Oracle WebLogic Server Proxy Plug-In for Apache HTTP Server";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ maintainers.aanderse ];
  };
}
