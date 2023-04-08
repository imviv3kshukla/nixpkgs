{ lib
, callPackage
, runCommand
, fetchFromGitHub
, fetchgit
, writeTextFile
, python3
, julia
, cacert
, curl
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

  depot = runCommand "julia-depot" {
    buildInputs = [curl julia] ++ extraLibs;
    registry = augmentedRegistry;
    inherit precompile;
  } ''
    export HOME=$(pwd)

    echo "Using registry $registry"
    echo "Using Julia ${julia}/bin/julia"

    export JULIA_PROJECT="$out"

    # mkdir -p $out/artifacts
    # cp $overridesToml $out/artifacts/Overrides.toml

    export JULIA_SSL_CA_ROOTS_PATH="${cacert}/etc/ssl/certs/ca-bundle.crt"

    # Turn off auto precompile so it can be controlled by us below
    export JULIA_PKG_PRECOMPILE_AUTO=0

    export JULIA_DEPOT_PATH=$out
    julia -e ' \
      import Pkg
      Pkg.Registry.add(Pkg.RegistrySpec(path="${augmentedRegistry}"))

      Pkg.instantiate()

      if "precompile" in keys(ENV) && ENV["precompile"] != "0"
        Pkg.precompile()
      end

      # Remove the registry to save space
      Pkg.Registry.rm("General")
    '
  '';

in

depot
