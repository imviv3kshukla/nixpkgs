#!/usr/bin/env python3

import json
from pathlib import Path
import subprocess
import sys
import toml
import yaml

dependencies_path = Path(sys.argv[1])
julia_path = Path(sys.argv[2])
extract_artifacts_script = Path(sys.argv[3])
out_path = Path(sys.argv[4])

with open(dependencies_path, "r") as f:
  dependencies = yaml.safe_load(f)

with open(out_path, "w") as f:
  f.write("{ fetchurl, writeTextFile }:\n\n")
  f.write("writeTextFile {\n")
  f.write("  name = \"Overrides.toml\";\n")
  f.write("  text = ''\n")

  # TODO: this loop is slow, use threadpool
  lines = []
  for uuid, src in dependencies.items():
    artifacts = toml.loads(subprocess.check_output([julia_path, extract_artifacts_script, uuid, src]).decode())
    if not artifacts: continue

    # print("src", src)
    # print("artifacts", artifacts)

    for artifact_name, details in artifacts.items():
      if len(details["download"]) == 0: continue
      download = details["download"][0]
      url = download["url"]
      sha256 = download["sha256"]

      lines.append("[%s]" % uuid)
      lines.append('%s = "${fetchurl %s}"' % (artifact_name, f"""{{
  url = "{url}";
  sha256 = "{sha256}";
}}"""))
      lines.append("")

  contents = "\n".join(lines)
  f.write(contents)
  f.write(f"""
  '';
}}\n""")
