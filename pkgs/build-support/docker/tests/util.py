
import json
import os

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
