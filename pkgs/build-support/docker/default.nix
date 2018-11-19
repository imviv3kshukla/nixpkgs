{
  callPackage,
  coreutils,
  docker,
  e2fsprogs,
  findutils,
  go,
  jq,
  jshon,
  lib,
  moreutils,
  nix,
  pigz,
  referencesByPopularity,
  rsync,
  runCommand,
  runtimeShell,
  shadow,
  skopeo,
  stdenv,
  storeDir ? builtins.storeDir,
  substituteAll,
  symlinkJoin,
  utillinux,
  vmTools,
  pkgs,
  writeReferencesToFile,
  writeText,
}:

# WARNING: this API is unstable and may be subject to backwards-incompatible changes in the future.

rec {
  util = (callPackage ./util.nix {});

  examples = import ./examples.nix {
    inherit pkgs buildImage buildImageUnzipped tarImage pullImage buildImageWithNixDb;
    inherit (util) shadowSetup;
  };

  pullImage = (callPackage ./pull-image.nix {}).pullImage;

  buildLayeredImage = (callPackage ./build-layered-image.nix {}).buildLayeredImage;

  exportImage = (callPackage ./export-image.nix {}).exportImage;

  buildImageUnzipped = (callPackage ./build-image.nix {}).buildImage;

  # buildImage is a synonym for buildImageUnzipped + tarImage
  buildImage = args: tarImage { fromImage = buildImageUnzipped args; };

  tarImage = args@{
    fromImage,
    }: runCommand "docker-image.tar.gz" {
      buildInputs = [pigz];
      fromImage = fromImage;
    } ''
      tar -C ${fromImage} --dereference --hard-dereference --xform s:'^./':: -c . | pigz -nT > $out
    '';


  # Build an image and populate its nix database with the provided
  # contents. The main purpose is to be able to use nix commands in
  # the container.
  # Be careful since this doesn't work well with multilayer.
  buildImageWithNixDb = (callPackage ./build-image-with-nix-db.nix {}).buildImageWithNixDb;
}
