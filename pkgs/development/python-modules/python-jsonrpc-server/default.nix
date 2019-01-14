{ stdenv, buildPythonPackage, fetchFromGitHub, pythonOlder
, pytest, mock, pytestcov, coverage
, future, futures
}:

buildPythonPackage rec {
  pname = "python-jsonrpc-server";
  version = "0.0.2";

  src = fetchFromGitHub {
    owner = "palantir";
    repo = "python-jsonrpc-server";
    rev = version;
    sha256 = "07n2f0k7w5ld1bkfadzjvqr1s9crg6zsxnl5x3qz28jhpw5qaxm0";
  };

  checkInputs = [
    pytest mock pytestcov coverage
  ];

  checkPhase = ''
    pytest
  '';

  propagatedBuildInputs = [ future ]
    ++ stdenv.lib.optional (pythonOlder "3.2") futures;

  meta = with stdenv.lib; {
    homepage = https://github.com/palantir/python-jsonrpc-server;
    description = "A Python 2 and 3 asynchronous JSON RPC server";
    license = licenses.mit;
    maintainers = [ maintainers.mic92 ];
  };
}
