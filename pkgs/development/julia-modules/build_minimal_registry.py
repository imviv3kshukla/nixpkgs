#!/usr/bin/env python3

import sys
import toml
import yaml

registry_path = sys.args[1]
out_path = sys.args[2]

registry = toml.load(registry_path.joinpath("Registry.toml"))

print("Got registry", registry)
