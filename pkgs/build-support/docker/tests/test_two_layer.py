
import docker
import json
import os
import pathlib
import pytest
import subprocess

from util import validate_image

def get_unzipped_image_expression(name, tag):
    raw = """
      with import <nixpkgs> {};
      with dockerTools;
      buildImageUnzipped {
        name = "%s";
        tag = "%s";
        fromImage = buildImageUnzipped { name = "bash-layer"; contents = pkgs.bashInteractive; };
        contents = pkgs.file;
      }
      """ % (name, tag)

    return raw.strip().replace("\n", " ")

@pytest.fixture(scope="session")
def image_dir(tmpdir_factory):
    unzipped_image_expression = get_unzipped_image_expression("some_image_name", "some_tag")

    tmpdir = tmpdir_factory.mktemp("unzipped")

    subprocess.run(["nix-build", "-E", unzipped_image_expression, "-o", "output"],
                   cwd=tmpdir,
                   check=True)

    return tmpdir.join("output").join("image")

def test_two_layer_unzipped_valid(image_dir):
    validate_image(image_dir)

    # One layer should be a symlink to the base image, and one should be a directory
    layer_dirs = [image_dir.join(x) for x in next(os.walk(image_dir))[1]]
    assert len(layer_dirs) == 2
    assert len([x for x in layer_dirs if os.path.islink(x)]) == 1

def test_two_layer_unzipped_nix_dependencies(image_dir):
    # The resulting image directory should have a nix dependency on the base image
    output = subprocess.check_output(["nix-store", "--query", "--tree", pathlib.Path(image_dir).parent])
    assert "bash-layer" in output.decode()

def test_two_layer_zipped(tmpdir):
    image_name = "two_layer"
    tag_name = "two_layer_tag"
    unzipped_image_expression = get_unzipped_image_expression(image_name, tag_name)

    # Load the image into Docker and make sure it works
    subprocess.run(["nix-build", "-E",
                    "with import <nixpkgs> {}; with dockerTools; tarImage { fromImage = %s; }" % unzipped_image_expression,
                    "-o", "output"],
                   cwd=tmpdir,
                   check=True)

    tarball = tmpdir.join("output").join("image.tar")

    # Extract the tarball into a temp folder and make sure it looks good
    examine_folder = tmpdir.join("examine_tarball")
    os.mkdir(examine_folder)
    subprocess.run(["tar", "-xvf", str(tarball), "-C", str(examine_folder)],
                   cwd=tmpdir,
                   check=True)

    # Folders at the root of the image should not be symlinks
    layer_dirs = [examine_folder.join(x) for x in next(os.walk(examine_folder))[1]]
    assert len(layer_dirs) == 2
    assert len([x for x in layer_dirs if os.path.islink(x)]) == 0

    # Make sure the image can be loaded into Docker
    full_image_name = image_name + ":" + tag_name
    try:
        subprocess.run(["docker", "load", "--input=" + str(tarball)], cwd=tmpdir, check=True)
        output = subprocess.check_output(["docker", "run", "-i", "--rm", full_image_name, "bash", "-c", "echo hi > some_file; file some_file"])
        assert output.decode().strip() == "some_file: ASCII text"
    finally:
        client = docker.from_env()
        client.images.remove(image=full_image_name, force=True)
