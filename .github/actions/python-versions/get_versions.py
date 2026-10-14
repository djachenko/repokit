import re, json, pathlib, sys, urllib.request

_MANIFEST_URL = "https://raw.githubusercontent.com/actions/python-versions/main/versions-manifest.json"

text = pathlib.Path("pyproject.toml").read_text()
m = re.search(r'requires-python\s*=\s*"[^0-9]*3\.(\d+)', text)
if m:
    min_minor = int(m.group(1))
else:
    min_minor = 11

with urllib.request.urlopen(_MANIFEST_URL) as response:
    manifest = json.load(response)

stable_minors = {
    int(entry["version"].split(".")[1])
    for entry in manifest
    if entry["stable"] and entry["version"].startswith("3.")
}
versions = [f"3.{minor}" for minor in sorted(stable_minors) if minor >= min_minor]
if not versions:
    sys.exit(f"no stable Python release satisfies requires-python >= 3.{min_minor}")

print("versions=" + json.dumps(versions))
