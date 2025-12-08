#!/usr/bin/env python3
import subprocess
import semver
from pathlib import Path

def run(cmd):
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
    return result.stdout.strip()

def get_latest_tag():
    try:
        tags = run(["git", "tag", "--list", "v*", "--sort=-version:refname"])
        if not tags:
            return None
        return tags.splitlines()[0].strip()
    except subprocess.CalledProcessError:
        return None

def main():
    try:
        subprocess.run(["git", "fetch", "--tags"], check=True)
    except subprocess.CalledProcessError:
        pass

    latest = get_latest_tag()

    if latest is None:
        new_version = "v0.1.0"
    else:
        core = latest.lstrip("v")
        ver = semver.VersionInfo.parse(core)
        bumped = ver.bump_minor()          
        new_version = f"v{bumped}"

    subprocess.run(["git", "tag", new_version], check=True)
    subprocess.run(["git", "push", "origin", new_version], check=True)

    Path(".version").write_text(new_version, encoding="utf-8")
    print(new_version)

if __name__ == "__main__":
    main()
