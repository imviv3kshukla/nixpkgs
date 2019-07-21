{ stdenv, fetchFromGitHub, makeWrapper
, cmake, llvmPackages, rapidjson, runtimeShell }:

stdenv.mkDerivation rec {
  name    = "ccls-${version}";
  version = "0.20190314.1";

  src = fetchFromGitHub {
    owner = "MaskRay";
    repo = "ccls";
    rev = "df002f7ae15eb0c734938e3ba59165507cf3ad96";
    sha256 = "0gfi1zhds9v8w2bhfdfxwyj97r7ba5r7qkkq1kvzdhnl5c0427fx";
  };

  nativeBuildInputs = [ cmake makeWrapper ];
  buildInputs = with llvmPackages; [ clang-unwrapped llvm rapidjson ];

  cmakeFlags = [
    "-DSYSTEM_CLANG=ON"
    "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.12"
  ];

  preConfigure = ''
    cmakeFlagsArray+=(-DCMAKE_CXX_FLAGS="-fvisibility=hidden -fno-rtti")
  '';

  patches = [

  ];

  shell = runtimeShell;
  postFixup = ''
    # We need to tell ccls where to find the standard library headers.

    standard_library_includes="\\\"-isystem\\\", \\\"${stdenv.lib.getDev stdenv.cc.libc}/include\\\""
    standard_library_includes+=", \\\"-isystem\\\", \\\"${llvmPackages.libcxx}/include/c++/v1\\\""
    export standard_library_includes

    wrapped=".ccls-wrapped"
    export wrapped

    mv $out/bin/ccls $out/bin/$wrapped
    substituteAll ${./wrapper} $out/bin/ccls
    chmod --reference=$out/bin/$wrapped $out/bin/ccls
  '';

  meta = with stdenv.lib; {
    description = "A c/c++ language server powered by clang";
    homepage    = https://github.com/MaskRay/ccls;
    license     = licenses.asl20;
    platforms   = platforms.linux ++ platforms.darwin;
    maintainers = [ maintainers.mic92 ];
  };
}
