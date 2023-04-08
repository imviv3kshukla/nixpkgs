{ callPackage
, runCommand
, fetchFromGitHub
, python3
, julia
}:

let
  augmentedRegistry = fetchFromGitHub {
    owner = "CodeDownIO";
    repo = "General";
    rev = "6ff5a36621f25b2e0db69e917164d52894e016d6";
    sha256 = "0y3130h97iyx947j0m0v6qfnklwmfg9jnllwa30kbblxm4fdh9wd";
  };

  closureYaml = callPackage ./package-closure.nix {
    inherit julia;
  };

in

runCommand "minimal-julia-registry" { buildInputs = [(python3.withPackages (ps: [ps.toml]))]; } ''
  python ${./build_minimal_registry.py}
''
