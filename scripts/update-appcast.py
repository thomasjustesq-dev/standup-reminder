#!/usr/bin/env python3
"""Insert a release item into the Sparkle appcast.

Usage:
  python3 scripts/update-appcast.py \
    --version 4.2.1 --build 7 \
    --zip dist/StandUpReminder-4.2.1.zip \
    --url https://github.com/<owner>/<repo>/releases/download/v4.2.1/StandUpReminder-4.2.1.zip \
    --signature <sparkle-ed-signature> \
    --appcast docs/appcast.xml [--notes "Short HTML changelog"]

Idempotent per version: an existing item for the same version is replaced.
"""
import argparse
import email.utils
import os
import re
import sys
import time

ITEM_TEMPLATE = """    <item>
      <title>Version {version}</title>
      <pubDate>{pubdate}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="{url}"
        length="{length}"
        type="application/octet-stream"
        sparkle:edSignature="{signature}" />
      <description><![CDATA[
        {notes}
      ]]></description>
    </item>
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--zip", required=True, dest="zip_path")
    parser.add_argument("--url", required=True)
    parser.add_argument("--signature", required=True)
    parser.add_argument("--appcast", required=True)
    parser.add_argument("--notes", default="See the GitHub release notes for details.")
    args = parser.parse_args()

    if not os.path.isfile(args.zip_path):
        print(f"missing zip: {args.zip_path}", file=sys.stderr)
        return 1
    if not os.path.isfile(args.appcast):
        print(f"missing appcast: {args.appcast}", file=sys.stderr)
        return 1

    length = os.path.getsize(args.zip_path)
    pubdate = email.utils.formatdate(time.time(), localtime=False, usegmt=True)
    item = ITEM_TEMPLATE.format(
        version=args.version,
        build=args.build,
        pubdate=pubdate,
        url=args.url,
        length=length,
        signature=args.signature,
        notes=args.notes,
    )

    with open(args.appcast, "r", encoding="utf-8") as fh:
        text = fh.read()

    # Replace an existing item for this version (re-tag / re-run), else insert
    # as the newest item right after the channel header.
    existing = re.search(
        r"    <item>\s*<title>Version "
        + re.escape(args.version)
        + r"</title>.*?</item>\n",
        text,
        flags=re.DOTALL,
    )
    if existing:
        text = text[: existing.start()] + item + text[existing.end():]
        action = "replaced"
    else:
        anchor = "    <language>en</language>\n"
        if anchor not in text:
            print("appcast channel header not found", file=sys.stderr)
            return 1
        text = text.replace(anchor, anchor + item, 1)
        action = "inserted"

    with open(args.appcast, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"{action} appcast item for {args.version} (build {args.build}, {length} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
