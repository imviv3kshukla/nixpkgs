#!/usr/bin/env python3

import yaml

with open("broken.yaml") as f:
    broken = yaml.safe_load(f)["broken-packages"]
broken = set(broken)

with open("./transitive-broken.yaml") as f:
    transitiveBroken = yaml.safe_load(f)["dont-distribute-packages"]
transitiveBroken = set(transitiveBroken)

with open("./stackage.yaml") as f:
    stackage = yaml.safe_load(f)["default-package-overrides"]
stackage = set([x.split()[0] for x in stackage])

brokenInStackage = len(broken & stackage)
transitiveAndBrokenInStackage = len((broken | transitiveBroken) & stackage)
totalStackage = len(stackage)

print("Broken packages:")
for pkg in sorted(list(broken | transitiveBroken)):
    print("\t" + pkg)

print("Total in Stackage: %d" % totalStackage)
print("Broken in Stackage: %d (%f)" % (brokenInStackage, float(brokenInStackage) / totalStackage))
print("Transitive + Broken in Stackage: %d (%f)" % (transitiveAndBrokenInStackage, float(transitiveAndBrokenInStackage) / totalStackage))
