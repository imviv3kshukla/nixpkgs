
import json
import os
import subprocess

class TestBasic(object):
    def test_basic(self, tmpdir):

        print("Got tmpdir: %s" % tmpdir)

        subprocess.run(["nix-build", "<nixpkgs>", "-A", "dockerExamples.bash", "-o", "bash"],
                       cwd=tmpdir,
                       check=True)

        subprocess.run(["tree", tmpdir.join("bash")])

        image_dir = tmpdir.join("bash").join("image")
        assert os.path.isdir(image_dir)

        # Make sure the image is well-formed, with a single layer + JSON file
        validate_image(image_dir)
        layer_dirs = next(os.walk(image_dir))[1]
        assert len(layer_dirs) == 1

        # Load the image into Docker and make sure it works


        assert 2 == 3


def validate_image(image_dir):
    """Perform sanity checks to validate that a Docker image folder is well-formed"""
    manifest_path = image_dir.join("manifest.json")

    assert os.path.isfile(manifest_path)

    with open(manifest_path) as f:
        manifest = json.loads(f.read())

    for section in manifest:
        for layer in section["Layers"]:
            assert os.path.isfile(image_dir.join(layer))

        assert os.path.isfile(image_dir.join(section["Config"]))
