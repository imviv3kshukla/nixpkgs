
from contextlib import contextmanager
import docker
import json
import os
import subprocess

def validate_image(image_dir):
    """Perform sanity checks to validate that a Docker image folder is well-formed"""
    assert os.path.isdir(image_dir)

    manifest_path = image_dir.join("manifest.json")

    assert os.path.isfile(manifest_path)

    with open(manifest_path) as f:
        manifest = json.loads(f.read())

    for section in manifest:
        for layer in section["Layers"]:
            assert os.path.isfile(image_dir.join(layer))

        assert os.path.isfile(image_dir.join(section["Config"]))


@contextmanager
def docker_load(full_image_name, tarball):
    try:
        subprocess.run(["docker", "load", "--input=" + str(tarball)], check=True)
        yield
    finally:
        client = docker.from_env()
        client.images.remove(image=full_image_name, force=True)
