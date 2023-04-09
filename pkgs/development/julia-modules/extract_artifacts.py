#!/usr/bin/env python3

import os
from pathlib import Path
import shutil
import sys
import toml
import yaml

dependencies_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])

with open(dependencies_path, "r") as f:
  dependencies = yaml.safe_load(f)

for uuid, path in dependencies:
  print("TODO: process path", path)
