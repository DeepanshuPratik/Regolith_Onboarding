#!/usr/bin/env python3
"""Emit a GResource XML manifest for a distro's branding directory.

A distro owner points the build at their own branding directory:

    meson setup build -DBranding_dir=/path/to/my-distro-branding

Everything in that directory is compiled into the binary, so a shipped build
carries its own identity and cannot be tampered with or go missing at runtime.

Meson has no glob, and requiring maintainers to hand-maintain a resource
manifest listing every slide and image would be a poor experience, so the
manifest is generated at configure time from whatever the directory contains.

Writes the XML to stdout; meson captures it via configure_file(capture: true).
"""

import os
import sys
from xml.sax.saxutils import escape

# Anything not useful inside the binary.
SKIP_NAMES = {".git", ".gitignore", "__pycache__", ".DS_Store"}
SKIP_SUFFIXES = (".swp", "~", ".orig", ".rej")

PREFIX = "/org/linux/Onboarding/branding"


def collect(root):
    """Relative paths of every shippable file under root, sorted."""
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_NAMES)
        for name in sorted(filenames):
            if name in SKIP_NAMES or name.endswith(SKIP_SUFFIXES):
                continue
            abs_path = os.path.join(dirpath, name)
            found.append(os.path.relpath(abs_path, root))
    return sorted(found)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: gen-branding-gresource.py <branding-dir>")

    root = sys.argv[1]
    if not os.path.isdir(root):
        sys.exit("branding_dir is not a directory: %s" % root)

    files = collect(root)
    if not files:
        sys.exit("branding_dir contains no files: %s" % root)

    if not os.path.isfile(os.path.join(root, "branding.conf")):
        sys.exit("branding_dir has no branding.conf: %s" % root)

    out = ['<?xml version="1.0" encoding="UTF-8"?>', "<gresources>",
           '  <gresource prefix="%s">' % PREFIX]
    for rel in files:
        # GResource paths always use forward slashes.
        out.append("    <file>%s</file>" % escape(rel.replace(os.sep, "/")))
    out += ["  </gresource>", "</gresources>", ""]

    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
