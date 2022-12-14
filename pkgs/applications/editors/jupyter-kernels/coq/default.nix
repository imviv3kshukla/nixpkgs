{ lib
, stdenv
, callPackage
, runCommand
, makeWrapper
, coq
, imagemagick
, python3
}:

# To test (in root nixpkgs dir):
# $(nix-build -E 'with import ./. {}; jupyter.override { definitions = { coq = coq-kernel.definition; }; }')/bin/jupyter-notebook

# To test with packages:
# $(nix-build -E 'with import ./. {}; jupyter.override { definitions = { coq = coq-kernel.definitionWithPackages [coqPackages.ceres]; }; }')/bin/jupyter-notebook

let
  kernel = callPackage ./kernel.nix {};

in

rec {
  launcher = runCommand "coq-kernel-launcher" {
    python = python3.withPackages (ps: [ ps.traitlets ps.jupyter_core ps.ipykernel kernel ]);
    nativeBuildInputs = [ makeWrapper ];
  } ''
    mkdir -p $out/bin

    makeWrapper ${python3.interpreter} $out/bin/coq-kernel \
      --add-flags "-m coq_jupyter" \
      --suffix PATH : ${coq}/bin
  '';

  sizedLogo = size: stdenv.mkDerivation {
    pname = "coq-logo-${size}x${size}.png";
    inherit (coq) version;

    src = coq.src;

    buildInputs = [ imagemagick ];

    dontConfigure = true;
    dontInstall = true;

    buildPhase = ''
      convert ./ide/coqide/coq.png -resize ${size}x${size} $out
    '';
  };

  definition = definitionWithPackages [];

  definitionWithPackages = packages: {
    displayName = "Coq " + coq.version;
    argv = [
      "${launcher}/bin/coq-kernel"
      "-f"
      "{connection_file}"
    ];
    language = "coq";
    logo32 = sizedLogo "32";
    logo64 = sizedLogo "64";
    env = {
      COQPATH = lib.concatStringsSep ":" (map (x: "${x}/lib/coq/${coq.coq-version}/user-contrib/") packages);
    };
  };
}
