{ stdenv, buildPackages }:

# This function is for creating a flat-file binary cache, i.e. the kind created by
# nix copy --to file:///some/path and usable as a substituter (with the file:// prefix).

# For example, in the Nixpkgs repo:
# nix-build -E 'with import ./. {}; mkBinaryCache { rootPaths = [hello]; }'

{ name ? "binary-cache"
, rootPaths
}:

stdenv.mkDerivation {
  inherit name;

  __structuredAttrs = true;

  exportReferencesGraph.closure = rootPaths;

  preferLocalBuild = true;

  PATH = "${buildPackages.coreutils}/bin:${buildPackages.jq}/bin:${buildPackages.python3}/bin:${buildPackages.nix}/bin:${buildPackages.xz}/bin";

  builder = builtins.toFile "builder" ''
    . .attrs.sh

    export out=''${outputs[out]}

    mkdir $out
    mkdir $out/nar

    python ${./make-binary-cache.py}
  '';
}
