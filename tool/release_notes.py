#!/usr/bin/env python3
"""Write release notes for one version: only that version's CHANGELOG section.

The release job used to hand GitHub the whole CHANGELOG as the release body, so
the download page opened with 530 lines of every change since 1.0 and the
assets were a long scroll below. A release page should answer "what changed in
this version" and then get out of the way.

Usage: tool/release_notes.py 1.3.4 notes.md
"""
import re
import sys
import pathlib

def main() -> int:
    if len(sys.argv) != 3:
        print('usage: release_notes.py VERSION OUTPUT', file=sys.stderr)
        return 2
    version, output = sys.argv[1], sys.argv[2]

    root = pathlib.Path(__file__).resolve().parent.parent
    text = (root / 'CHANGELOG.md').read_text()

    # A version section runs from its own heading to the next one of any level.
    pattern = re.compile(
        rf'^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|\Z)',
        re.DOTALL | re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        print(f'no CHANGELOG section for {version}', file=sys.stderr)
        return 1

    body = match.group(1).strip()

    header = (
        f'### Throw {version}\n\n'
        'Downloads are below. Pick your platform, or the Android APK for most '
        'phones.\n\n---\n\n'
    )
    (root / output).write_text(header + body + '\n')
    print(f'{output}: {len(header + body)} chars from CHANGELOG [{version}]')
    return 0

if __name__ == '__main__':
    sys.exit(main())
