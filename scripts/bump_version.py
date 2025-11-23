#!/usr/bin/env python3
import subprocess
import semver
from pathlib import Path

def run(cmd):
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
    return result.stdout.strip()

def get_latest_tag():
    try:
        # ia toate tag-urile care încep cu v, sortate desc după versiune
        tags = run(["git", "tag", "--list", "v*", "--sort=-version:refname"])
        if not tags:
            return None
        return tags.splitlines()[0].strip()
    except subprocess.CalledProcessError:
        return None

def main():
    # ca să fim siguri că vedem tag-urile din remote
    try:
        subprocess.run(["git", "fetch", "--tags"], check=True)
    except subprocess.CalledProcessError:
        pass

    latest = get_latest_tag()

    if latest is None:
        # dacă nu există tag-uri, pornim de la v0.1.0 (prima minor release)
        new_version = "v0.1.0"
    else:
        core = latest.lstrip("v")
        ver = semver.VersionInfo.parse(core)
        bumped = ver.bump_minor()          # <<< aici se respectă cerința: minor++
        new_version = f"v{bumped}"

    # creăm și împingem noul tag
    subprocess.run(["git", "tag", new_version], check=True)
    subprocess.run(["git", "push", "origin", new_version], check=True)

    # scriem versiunea în .version pentru Jenkins
    Path(".version").write_text(new_version, encoding="utf-8")
    print(new_version)

if __name__ == "__main__":
    main()
