{ lib
, callPackage
, runCommand
, fetchFromGitHub
, fetchgit
, makeWrapper
, writeTextFile
, python3

, julia
, extraLibs ? []
, packageNames ? ["IJulia" "Plots"]
, precompile ? true
, makeWrapperArgs ? ""
}:

let
  augmentedRegistry = fetchFromGitHub {
    owner = "CodeDownIO";
    repo = "General";
    rev = "6ff5a36621f25b2e0db69e917164d52894e016d6";
    sha256 = "0y3130h97iyx947j0m0v6qfnklwmfg9jnllwa30kbblxm4fdh9wd";
  };

  closureYaml = callPackage ./package-closure.nix {
    inherit julia augmentedRegistry packageNames;
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

  projectAndDepot = callPackage ./depot.nix {
    inherit extraLibs packageNames precompile;
    registry = minimalRegistry;
  };

in

runCommand "julia-${julia.version}-env" { buildInputs = [makeWrapper]; } ''
  mkdir -p $out/bin
  makeWrapper ${julia}/bin/julia $out/bin/julia \
    --suffix LD_LIBRARY_PATH : "${lib.makeLibraryPath extraLibs}" \
    --set PYTHON ${python3}/bin/python \
    --suffix JULIA_DEPOT_PATH : "${projectAndDepot}/depot" \
    --suffix JULIA_PROJECT : "${projectAndDepot}/project" \
    --suffix PATH : ${python3}/bin $makeWrapperArgs
''
