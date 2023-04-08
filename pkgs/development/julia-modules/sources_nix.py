#!/usr/bin/env python3

import os
from pathlib import Path
import shutil
import sys
import toml
import yaml

registry_path = Path(sys.argv[1])
desired_packages_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])

with open(desired_packages_path, "r") as f:
  desired_packages = yaml.safe_load(f)

registry = toml.load(registry_path / "Registry.toml")

with open(os.environ["OUT"], "w") as f:
  f.write("{\n")
  for pkg in desired_packages:
      uuid = pkg["uuid"]
      if not uuid in registry["packages"]: continue

      registry_info = registry["packages"][uuid]
      path = registry_info["path"]
      packageToml = toml.load(registry_path / f / "Package.toml")

      repo = packageToml["repo"]
      rev = "foo" # pkg[""]
      f.write(f"""{uuid} = fetchgit {
        url = {repo};
        rev = {rev};
      };\n""")
  f.write("}")
