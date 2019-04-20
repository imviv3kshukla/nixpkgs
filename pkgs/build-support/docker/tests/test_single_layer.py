
import json
import os
import subprocess

from util import validate_image

def get_unzipped_image_expression(tag):
    raw = """
      with import <nixpkgs> {};
      with dockerTools;
      buildImageUnzipped {
        name = "bash";
        tag = "%s";
        contents = pkgs.bashInteractive;
      }
      """ % tag

    return raw.strip().replace("\n", " ")

class TestBasic(object):
    def test_single_layer_unzipped(self, tmpdir):
        unzipped_image_expression = get_unzipped_image_expression("random_tag")

        subprocess.run(["nix-build", "-E", unzipped_image_expression, "-o", "bash"],
                       cwd=tmpdir,
                       check=True)

        image_dir = tmpdir.join("bash").join("image")
        assert os.path.isdir(image_dir)

        # Make sure the image is well-formed, with a single layer + JSON file
        validate_image(image_dir)
        layer_dirs = next(os.walk(image_dir))[1]
        assert len(layer_dirs) == 1

    def test_single_layer_zipped(self, tmpdir):
        unzipped_image_expression = get_unzipped_image_expression("random_tag")

        # Load the image into Docker and make sure it works
        subprocess.run(["nix-build", "-E",
                        "with import <nixpkgs> {}; with dockerTools; tarImage { fromImage = %s; }" % unzipped_image_expression,
                        "-o", "bashTarred"],
                       cwd=tmpdir,
                       check=True)

        tarball = tmpdir.join("bashTarred").join("image.tar")

        subprocess.run(["docker", "load", "--input=" + str(tarball)],
                       cwd=tmpdir,
                       check=True)

        output = subprocess.check_output(["docker", "run", "-i", "--rm", "bash", "bash", "-c", "echo -n hi"])

        assert output.decode() == "hi"
