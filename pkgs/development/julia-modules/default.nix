{ runCommand
, fetchFromGitHub
, julia
}:

let
  augmentedRegistry = fetchFromGitHub {
    owner = "CodeDownIO";
    repo = "General";
    rev = "6ff5a36621f25b2e0db69e917164d52894e016d6";
    sha256 = "0y3130h97iyx947j0m0v6qfnklwmfg9jnllwa30kbblxm4fdh9wd";
  };

in

runCommand "julia-with-packages" { buildInputs = [julia]; } ''
  export JULIA_PKG_PRECOMPILE_AUTO=0
  julia -e ' \
    import Pkg
    Pkg.Registry.add(Pkg.RegistrySpec(path="${augmentedRegistry}"))

    Pkg.add("IJulia", "Plots")

    # if "precompile" in keys(ENV) && ENV["precompile"] != "0"
    #   Pkg.precompile()
    # end

    # # Remove the registry to save space
    # Pkg.Registry.rm("General")
  ';
''
