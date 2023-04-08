{ runCommand
, cacert
, curl
, julia
, extraLibs
, augmentedRegistry
, precompile
}:

runCommand "julia-depot" {
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
''
