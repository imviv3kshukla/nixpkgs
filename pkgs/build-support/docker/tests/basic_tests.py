
import json
import os
import subprocess

from util import validate_image

class TestBasic(object):
    def test_single_layer_unzipped(self, tmpdir):
        subprocess.run(["nix-build", "<nixpkgs>", "-A", "dockerExamples.bash", "-o", "bash"],
                       cwd=tmpdir,
                       check=True)

        image_dir = tmpdir.join("bash").join("image")
        assert os.path.isdir(image_dir)

        # Make sure the image is well-formed, with a single layer + JSON file
        validate_image(image_dir)
        layer_dirs = next(os.walk(image_dir))[1]
        assert len(layer_dirs) == 1

    def test_single_layer_zipped(self, tmpdir):
        # Load the image into Docker and make sure it works
        subprocess.run(["nix-build", "-E", "with import <nixpkgs> {}; with dockerTools; tarImage { fromImage = dockerExamples.bash; }", "-o", "bashTarred"],
                       cwd=tmpdir,
                       check=True)

        tarball = tmpdir.join("bashTarred").join("image.tar")

        subprocess.run(["docker", "load", "--input=" + str(tarball)],
                       cwd=tmpdir,
                       check=True)

        output = subprocess.check_output(["docker", "run", "-i", "--rm", "bash", "bash", "-c", "echo -n hi"])

        assert output.decode() == "hi"
