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
  mkdir home
  export HOME=$(pwd)/home

  julia -e ' \
    import Pkg
    Pkg.Registry.add(Pkg.RegistrySpec(path="${augmentedRegistry}"))

    ########################

    import Pkg.Types: PackageSpec, VersionSpec, PRESERVE_NONE
    import Pkg.Operations: assert_can_add, _resolve, update_package_add

    ########################

    # pkgs = Vector{Pkg.Types.PackageSpec}(["IJulia", "Plots"])

    # pkgs = Vector{PackageSpec}([
    #     PackageSpec(name="IJulia", version="1.9.3"),
    #     PackageSpec(name="Plots", version="1.9.1")
    # ])

    pkgs = Vector{PackageSpec}([
        PackageSpec(name="IJulia", version=VersionSpec("1.9.3"), uuid="7073ff75-c697-5162-941a-fcdaad2a7d2a"),
        PackageSpec(name="Plots", version=VersionSpec("1.9.1"), uuid="91a5bcdd-55d7-5caf-9e0b-520d859cae80")
    ])

    ########################

    ctx = Pkg.Types.Context()

    assert_can_add(ctx, pkgs)

    # load manifest data
    for (i, pkg) in pairs(pkgs)
        entry = Pkg.Types.manifest_info(ctx.env.manifest, pkg.uuid)
        is_dep = any(uuid -> uuid == pkg.uuid, [uuid for (name, uuid) in ctx.env.project.deps])
        pkgs[i] = update_package_add(ctx, pkg, entry, is_dep)
    end

    foreach(pkg -> ctx.env.project.deps[pkg.name] = pkg.uuid, pkgs) # update set of deps

    # resolve
    pkgs, deps_map = _resolve(ctx.io, ctx.env, ctx.registries, pkgs, PRESERVE_NONE, ctx.julia_version)

    # print(pkgs)
    # print(deps_map)
    for packageSpec in pkgs
        println(packageSpec.name)
        println(packageSpec.uuid)
        println(packageSpec.version)
        println("---------")
    end
  ';
''
