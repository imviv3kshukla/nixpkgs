
import docker
import json
import os
import subprocess

from util import validate_image

def get_unzipped_image_expression(name, tag):
    raw = """
      with import <nixpkgs> {};
      with dockerTools;
      buildImageUnzipped {
        name = "%s";
        tag = "%s";
        contents = pkgs.bashInteractive;
      }
      """ % (name, tag)

    return raw.strip().replace("\n", " ")

class TestBasic(object):
    def test_one_layer_unzipped(self, tmpdir):
        unzipped_image_expression = get_unzipped_image_expression("some_image_name", "some_tag")

        subprocess.run(["nix-build", "-E", unzipped_image_expression, "-o", "output"], cwd=tmpdir, check=True)

        # Make sure the image is well-formed, with a single layer + JSON file
        image_dir = tmpdir.join("output").join("image")
        validate_image(image_dir)
        layer_dirs = next(os.walk(image_dir))[1]
        assert len(layer_dirs) == 1

    def test_one_layer_zipped(self, tmpdir):
        image_name = "bash_image"
        image_tag = "bash_tag"
        unzipped_image_expression = get_unzipped_image_expression(image_name, image_tag)

        subprocess.run(["nix-build", "-E",
                        "with import <nixpkgs> {}; with dockerTools; tarImage { fromImage = %s; }" % unzipped_image_expression,
                        "-o", "bashTarred"],
                       cwd=tmpdir,
                       check=True)

        tarball = tmpdir.join("bashTarred").join("image.tar")

        full_image_name = image_name + ":" + image_tag
        try:
            subprocess.run(["docker", "load", "--input=" + str(tarball)], cwd=tmpdir, check=True)
            output = subprocess.check_output(["docker", "run", "-i", "--rm", full_image_name, "bash", "-c", "echo -n hi"])
            assert output.decode() == "hi"
        finally:
            client = docker.from_env()
            client.images.remove(image=full_image_name, force=True)
