{ runCommand
, cacert
, curl
, julia
, extraLibs
, augmentedRegistry
}:

runCommand "julia-project" {
    buildInputs = [curl julia] ++ extraLibs;
    registry = augmentedRegistry;
    inherit precompile;
  } ''
  export HOME=$(pwd)

  echo "Using registry $registry"
  echo "Using Julia ${julia}/bin/julia"

  export JULIA_PROJECT="$(pwd)"

  # mkdir -p $out/artifacts
  # cp $overridesToml $out/artifacts/Overrides.toml

  export JULIA_SSL_CA_ROOTS_PATH="${cacert}/etc/ssl/certs/ca-bundle.crt"

  export JULIA_PKG_PRECOMPILE_AUTO=0

  mkdir ./depot
  export JULIA_DEPOT_PATH=./depot
  julia -e ' \
    import Pkg
    Pkg.Registry.add(Pkg.RegistrySpec(path="${augmentedRegistry}"))
  '

  cp Project.toml $out
  cp Manifest.toml $out
''
