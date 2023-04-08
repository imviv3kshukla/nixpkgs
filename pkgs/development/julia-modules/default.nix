{ lib
, callPackage
, runCommand
, fetchFromGitHub
, fetchgit
, writeTextFile
, python3
, julia
, extraLibs ? []
, precompile ? true
}:

let
  augmentedRegistry = fetchFromGitHub {
    owner = "CodeDownIO";
    repo = "General";
    rev = "6ff5a36621f25b2e0db69e917164d52894e016d6";
    sha256 = "0y3130h97iyx947j0m0v6qfnklwmfg9jnllwa30kbblxm4fdh9wd";
  };

  closureYaml = callPackage ./package-closure.nix {
    inherit julia augmentedRegistry;
    packageNames = ["IJulia" "Plots"];
  };

  dependencies = runCommand "julia-sources.nix" { buildInputs = [(python3.withPackages (ps: with ps; [toml pyyaml]))]; } ''
    export OUT="$out"
    python ${./sources_nix.py} \
      "${augmentedRegistry}" \
      "${closureYaml}" \
      "$out"
  '';

  dependenciesYaml = writeTextFile {
    name = "julia-dependencies.yml";
    text = lib.generators.toYAML {} (import dependencies { inherit fetchgit; });
  };

  minimalRegistry = runCommand "minimal-julia-registry" { buildInputs = [(python3.withPackages (ps: with ps; [toml pyyaml]))]; } ''
    python ${./minimal_registry.py} \
      "${augmentedRegistry}" \
      "${closureYaml}" \
      "${dependenciesYaml}" \
      "$out"
  '';

  depot = callPackage ./depot.nix { inherit augmentedRegistry precompile; };

in

depot
