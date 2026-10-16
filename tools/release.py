#!/usr/bin/env python3
"""Validate release metadata and optionally create its matching local tag."""

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys


def validate(root, tag=None):
    toc = (root / "ItemFYI.toc").read_text(encoding="utf-8")
    versions = re.findall(r"^## Version:\s*(\S+)\s*$", toc, re.MULTILINE)
    if len(versions) != 1 or not re.fullmatch(
        r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", versions[0]
    ):
        raise ValueError("TOC must contain exactly one real release version")
    version = versions[0]
    headings = re.findall(
        r"^## (\S+)\s*$", (root / "CHANGELOG.md").read_text(encoding="utf-8"), re.MULTILINE
    )
    releases = [heading for heading in headings if heading != "Unreleased"]
    if not releases or releases[0] != version:
        raise ValueError("TOC version must match the latest changelog release")
    expected = "v" + version
    if tag is not None and tag != expected:
        raise ValueError(f"Tag {tag!r} does not match TOC version; expected {expected}")
    return expected


def git(root, *args):
    return subprocess.check_output(
        ["git", *args], cwd=root, text=True, stderr=subprocess.STDOUT
    ).strip()


def create_tag(root):
    tag = validate(root)
    if git(root, "status", "--porcelain"):
        raise ValueError("Commit or stash changes before tagging")
    if git(root, "branch", "--show-current") != "main":
        raise ValueError("Release tags must be created from main after merge")
    git(root, "fetch", "origin", "main", "--tags")
    if git(root, "rev-parse", "HEAD") != git(root, "rev-parse", "origin/main"):
        raise ValueError("Local main must match origin/main before tagging")
    git(root, "tag", "-a", tag, "-m", "ItemFYI " + tag)
    return tag


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--tag", help="Validate a proposed tag against the TOC")
    group.add_argument("--create-tag", action="store_true", help="Create the matching local tag")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    tag = args.tag
    if tag is None and os.environ.get("GITHUB_REF_TYPE") == "tag":
        tag = os.environ.get("GITHUB_REF_NAME", "")
    try:
        if args.create_tag:
            created = create_tag(root)
            print(f"Created {created}. Publish with: git push origin {created}")
        else:
            print("Release metadata validated: " + validate(root, tag))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
