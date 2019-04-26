
import docker
import json
import os
import pathlib
import pytest
import subprocess

from util import validate_image

def get_image_expression(name, tag):
    raw = """
      with import <nixpkgs> {};
      with dockerTools;
      buildImageUnzipped {
        name = "%s";
        tag = "%s";
        fromImage = buildImage { name = "bash-layer"; contents = pkgs.bashInteractive; };
        contents = pkgs.file;
      }
      """ % (name, tag)

    return raw.strip().replace("\n", " ")

@pytest.fixture(scope="session")
def image_dir(tmpdir_factory):
    unzipped_image_expression = get_image_expression("some_image_name", "some_tag")

    tmpdir = tmpdir_factory.mktemp("unzipped")

    subprocess.run(["nix-build", "-E", unzipped_image_expression, "-o", "output"],
                   cwd=tmpdir,
                   check=True)

    return tmpdir.join("output").join("image")

def test_valid(image_dir):
    validate_image(image_dir)

    # None of the layers should be symlinks
    layer_dirs = [image_dir.join(x) for x in next(os.walk(image_dir))[1]]
    assert len(layer_dirs) == 2
    assert len([x for x in layer_dirs if os.path.islink(x)]) == 0
