#!/usr/bin/env python3

from collections import defaultdict
import copy
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

# print("Got desired packages", desired_packages)
uuid_to_versions = defaultdict(list)
for pkg in desired_packages:
    uuid_to_versions[pkg["uuid"]].append(pkg["version"])

registry = toml.load(registry_path / "Registry.toml")

uuid_and_version_to_fetch_info = {}

for (uuid, versions) in uuid_to_versions.items():
    print("Got uuid", uuid, versions)
    if not uuid in registry["packages"]: continue

    registry_info = registry["packages"][uuid]

    # Copy some files to the minimal repo unchanged
    path = registry_info["path"]
    os.makedirs(out_path / path)
    for f in ["Compat.toml", "Deps.toml", "Package.toml"]:
        shutil.copy2(registry_path / path / f, out_path / path)

    all_versions = toml.load(registry_path / path / "Versions.toml")
    versions_to_keep = {k: v for k, v in all_versions.items() if k in versions}
    for k, v in versions_to_keep.items():
        uuid_and_version_to_fetch_info[(uuid, k)] = copy.deepcopy(v)
        del v["nix-sha256"]
    with open(out_path / path / "Versions.toml", "w") as f:
        toml.dump(versions_to_keep, f)

print("uuid_and_version_to_fetch_info", uuid_and_version_to_fetch_info)
