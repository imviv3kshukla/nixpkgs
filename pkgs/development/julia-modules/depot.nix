{ lib
, runCommand
, cacert
, curl
, julia
, extraLibs
, packageNames
, precompile
, registry
}:

runCommand "julia-depot" {
    buildInputs = [curl julia] ++ extraLibs;
    inherit precompile registry;
  } ''
  export HOME=$(pwd)

  echo "Using registry $registry"

  mkdir -p $out/project
  export JULIA_PROJECT="$out/project"

  mkdir -p $out/depot
  export JULIA_DEPOT_PATH="$out/depot"

  # mkdir -p $out/artifacts
  # cp $overridesToml $out/artifacts/Overrides.toml

  export JULIA_SSL_CA_ROOTS_PATH="${cacert}/etc/ssl/certs/ca-bundle.crt"

  # Turn off auto precompile so it can be controlled by us below
  export JULIA_PKG_PRECOMPILE_AUTO=0

  julia -e ' \
    import Pkg
    Pkg.Registry.add(Pkg.RegistrySpec(path="${registry}"))

    Pkg.add(${lib.generators.toJSON {} packageNames})
    Pkg.instantiate()

    if "precompile" in keys(ENV) && ENV["precompile"] != "0"
      Pkg.precompile()
    end

    # Remove the registry to save space
    Pkg.Registry.rm("General")
  '
''
