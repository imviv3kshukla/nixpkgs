
import docker
import json
import os
import subprocess

from util import validate_image

pull_expression = """
  pullImage {
    imageName = "nixos/nix";
    imageDigest = "sha256:50ece001fa4ad2a26c85b05c1f1c1285155ed5dffd97d780523526fc36316fb8";
    sha256 = "0kvks3iyaivhg8kwnpygzashrp6kylr8dfczgwid7av8aybpxxqb";
    finalImageTag = "1.11";
  }
"""

layer_image_name = "layer_on_pull"
layer_image_tag = "layer_on_pull_tag"

layer_expression = """
  buildImageUnzipped {
    name = "%s";
    tag = "%s";
    fromImage = %s;
    contents = pkgs.file;
  }
""" % (layer_image_name, layer_image_tag, pull_expression)

def wrap(expression):
    raw = """
      with import <nixpkgs> {};
      with dockerTools;
      %s
      """ % expression

    return raw.strip().replace("\n", " ")

def test_pull(tmpdir):
    unzipped_image_expression = wrap(pull_expression)

    subprocess.run(["nix-build", "-E", unzipped_image_expression, "-o", "output"], cwd=tmpdir, check=True)

    image_dir = tmpdir.join("output").join("image")
    # TODO: we can't use validate_image until it understands the manifest schema v2
    # validate_image(image_dir)
    layer_dirs = [image_dir.join(x) for x in next(os.walk(image_dir))[1]]
    assert len([x for x in layer_dirs if os.path.islink(x)]) == 0

def test_layer_on_pulled_layer(tmpdir):
    unzipped_image_expression = wrap(layer_expression)

    subprocess.run(["nix-build", "-E", unzipped_image_expression, "-o", "output"], cwd=tmpdir, check=True)

    # Load the image into Docker and make sure it works
    subprocess.run(["nix-build", "-E",
                    "with import <nixpkgs> {}; with dockerTools; tarImage { fromImage = %s; }" % unzipped_image_expression,
                    "-o", "output"],
                   cwd=tmpdir,
                   check=True)

    tarball = tmpdir.join("output").join("image.tar")

    # Make sure the image can be loaded into Docker
    full_image_name = layer_image_name + ":" + layer_tag_name
    try:
        subprocess.run(["docker", "load", "--input=" + str(tarball)], cwd=tmpdir, check=True)
        output = subprocess.check_output(["docker", "run", "-i", "--rm", full_image_name, "bash", "-c", "echo hi > some_file; file some_file"])
        assert output.decode().strip() == "some_file: ASCII text"
    finally:
        client = docker.from_env()
        client.images.remove(image=full_image_name, force=True)
