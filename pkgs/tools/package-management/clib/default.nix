{ stdenv, fetchFromGitHub, curl  }:

stdenv.mkDerivation rec {
  version = "1.11.0";
  name = "clib-${version}";

  src = fetchFromGitHub {
    rev    = version;
    owner  = "clibs";
    repo   = "clib";
    sha256 = "0b0nw1n4vw2czjmqac19ybp6kbmknws56r1lajfpdlg903fyk1q1";
  };

  hardeningDisable = [ "fortify" ];

  makeFlags = "PREFIX=$(out)";

  NIX_CFLAGS_COMPILE = [
    "-Wno-error=format-security" # Added to build 1.11.0
  ];

  buildInputs = [ curl ];

  meta = with stdenv.lib; {
    description = "C micro-package manager";
    homepage = https://github.com/clibs/clib;
    license = licenses.mit;
    maintainers = with maintainers; [ jb55 ];
    platforms = platforms.all;
  };
}
