
import docker
import json
import os
import subprocess

from util import validate_image

def get_unzipped_image_expression():
    raw = """
      with import <nixpkgs> {};
      with dockerTools;
      pullImage {
        imageName = "nixos/nix";
        imageDigest = "sha256:20d9485b25ecfd89204e843a962c1bd70e9cc6858d65d7f5fadc340246e2116b";
        sha256 = "0mqjy3zq2v6rrhizgb9nvhczl87lcfphq9601wcprdika2jz7qh8";
        finalImageTag = "1.11";
      }
      """

    return raw.strip().replace("\n", " ")

class TestBasic(object):
    def test_pull(self, tmpdir):
        unzipped_image_expression = get_unzipped_image_expression()

        subprocess.run(["nix-build", "-E", unzipped_image_expression, "-o", "output"], cwd=tmpdir, check=True)

        print("tmpdir: ", tmpdir)

        assert 2 == 3
