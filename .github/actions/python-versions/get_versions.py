import re, json, pathlib, sys

text = pathlib.Path("pyproject.toml").read_text()
m = re.search(r'requires-python\s*=\s*"[^0-9]*3\.(\d+)', text)
min_minor = int(m.group(1)) if m else 10

all_versions = ["3.10", "3.11", "3.12", "3.13"]
versions = [v for v in all_versions if int(v.split(".")[1]) >= min_minor]
versions.append("3.x")

print("versions=" + json.dumps(versions))
