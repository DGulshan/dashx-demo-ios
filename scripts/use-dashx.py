#!/usr/bin/env python3
"""Flip the DashXDemo Xcode project's dashx-ios SPM reference between a
local-path checkout and a remote-tag pin.

Usage:
    scripts/use-dashx.py local                      # ../../dashx-ios (default)
    scripts/use-dashx.py local ../my-fork           # custom relative path
    scripts/use-dashx.py local /abs/path/dashx-ios  # custom absolute path
    scripts/use-dashx.py remote                     # pin to 1.3.1 (default)
    scripts/use-dashx.py remote 1.4.0               # pin to given exact version

Why: the released remote tag is what integrators should use (and what the
repo's pbxproj is committed with). When iterating on the SDK source in a
sibling `dashx-ios/` checkout, flip to `local` to have Xcode build against
the live sources without publishing a tag.

Run from anywhere — the script resolves paths relative to its own location.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
PBXPROJ = REPO_ROOT / "DashXDemo.xcodeproj" / "project.pbxproj"
PACKAGE_RESOLVED = (
    REPO_ROOT
    / "DashXDemo.xcodeproj"
    / "project.xcworkspace"
    / "xcshareddata"
    / "swiftpm"
    / "Package.resolved"
)

REMOTE_URL = "https://github.com/dashxhq/dashx-ios.git"
DEFAULT_LOCAL_PATH = "../../dashx-ios"
DEFAULT_VERSION = "1.3.1"

REMOTE_ANNOTATION = 'XCRemoteSwiftPackageReference "dashx-ios"'

# Single Begin/End block — backreference ensures matching prefix.
SECTION_RE = re.compile(
    r"/\* Begin XC(Local|Remote)SwiftPackageReference section \*/"
    r".*?"
    r"/\* End XC\1SwiftPackageReference section \*/",
    re.DOTALL,
)

# Every comment occurrence inside the pbxproj, across packageReferences +
# each XCSwiftPackageProductDependency entry. Matches any quoted path/name
# so a previously-written custom local path still rewrites correctly.
ANNOTATION_RE = re.compile(
    r'XC(?:Local|Remote)SwiftPackageReference "[^"]+"'
)


def local_annotation(path: str) -> str:
    return f'XCLocalSwiftPackageReference "{path}"'


def local_section(path: str) -> str:
    return (
        "/* Begin XCLocalSwiftPackageReference section */\n"
        f'\t\tA0A0A0A0A0A0A0A0A0A0F001 /* XCLocalSwiftPackageReference "{path}" */ = {{\n'
        "\t\t\tisa = XCLocalSwiftPackageReference;\n"
        f'\t\t\trelativePath = "{path}";\n'
        "\t\t};\n"
        "/* End XCLocalSwiftPackageReference section */"
    )


def remote_section(version: str) -> str:
    return (
        "/* Begin XCRemoteSwiftPackageReference section */\n"
        '\t\tA0A0A0A0A0A0A0A0A0A0F001 /* XCRemoteSwiftPackageReference "dashx-ios" */ = {\n'
        "\t\t\tisa = XCRemoteSwiftPackageReference;\n"
        f'\t\t\trepositoryURL = "{REMOTE_URL}";\n'
        "\t\t\trequirement = {\n"
        "\t\t\t\tkind = exactVersion;\n"
        f"\t\t\t\tversion = {version};\n"
        "\t\t\t};\n"
        "\t\t};\n"
        "/* End XCRemoteSwiftPackageReference section */"
    )


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = ap.add_subparsers(dest="mode", required=True)

    p_local = sub.add_parser("local", help="point at a local dashx-ios checkout")
    p_local.add_argument(
        "path",
        nargs="?",
        default=DEFAULT_LOCAL_PATH,
        help=f"path to the local dashx-ios checkout (default: {DEFAULT_LOCAL_PATH})",
    )

    p_remote = sub.add_parser("remote", help="pin to a remote tag")
    p_remote.add_argument(
        "version",
        nargs="?",
        default=DEFAULT_VERSION,
        help=f"exact version to pin (default: {DEFAULT_VERSION})",
    )

    args = ap.parse_args()

    if not PBXPROJ.exists():
        print(f"error: pbxproj not found at {PBXPROJ}", file=sys.stderr)
        return 1

    text = PBXPROJ.read_text()

    if args.mode == "local":
        new_section = local_section(args.path)
        new_annotation = local_annotation(args.path)
        label = f"LOCAL path ({args.path})"
    else:
        new_section = remote_section(args.version)
        new_annotation = REMOTE_ANNOTATION
        label = f"REMOTE tag ({REMOTE_URL} @ {args.version})"

    if not SECTION_RE.search(text):
        print(
            "error: could not find an XC(Local|Remote)SwiftPackageReference section in pbxproj",
            file=sys.stderr,
        )
        return 2

    text, n_section = SECTION_RE.subn(new_section, text)
    text, n_annot = ANNOTATION_RE.subn(new_annotation, text)

    PBXPROJ.write_text(text)
    print(f"✓ dashx-ios SPM ref → {label}")
    print(f"  ({n_section} section rewritten, {n_annot} annotations updated)")

    # Stale Package.resolved pins whichever side was active before; Xcode
    # will refuse to re-resolve if the pinned revision doesn't apply to the
    # new source. Delete so Xcode regenerates on next open/build.
    if PACKAGE_RESOLVED.exists():
        PACKAGE_RESOLVED.unlink()
        print(
            f"✓ removed stale {PACKAGE_RESOLVED.relative_to(REPO_ROOT)} (Xcode will regenerate)"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
