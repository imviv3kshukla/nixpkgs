{ lib
, buildPythonPackage
, fetchPypi
, pytest
}:

buildPythonPackage rec {
  pname = "parso";
  version = "0.7.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0b7irps2dqmzq41sxbpvxbivhh1x2hwmbqp45bbpd82446p9z3lh";
  };

  checkInputs = [ pytest ];

  meta = {
    description = "A Python Parser";
    homepage = https://github.com/davidhalter/parso;
    license = lib.licenses.mit;
  };

}
