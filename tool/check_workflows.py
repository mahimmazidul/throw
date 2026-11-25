#!/usr/bin/env python3
"""Validate GitHub workflow step keys.

GitHub validates workflows on push and fails the run instantly with no jobs and
no logs if a step has a key it does not recognise. That is a silent, confusing
failure: the run shows as failed and there is nothing to read.

This caught exactly that: `retry-attempts` and `retry-wait` were written at step
level on `ncipollo/release-action`, where they belong inside `with:`. The whole
release run failed before a single job started. Run this before pushing.
"""
import sys
import pathlib

import yaml

STEP_KEYS = {
    'name', 'id', 'if', 'uses', 'run', 'with', 'env', 'working-directory',
    'shell', 'continue-on-error', 'timeout-minutes', 'strategy',
    'uses-checkout', 'needs', 'permissions',
}


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent
    failures = 0
    for path in sorted((root / '.github' / 'workflows').glob('*.yml')):
        doc = yaml.safe_load(path.read_text())
        for job, cfg in (doc.get('jobs') or {}).items():
            for i, step in enumerate(cfg.get('steps') or []):
                bad = set(step) - STEP_KEYS
                if bad:
                    label = step.get('name') or step.get('uses')
                    print(f'{path.name}: job "{job}" step {i} ({label}): '
                          f'unsupported keys {sorted(bad)}')
                    failures += 1
    if failures:
        print(f'\n{failures} workflow problem(s). GitHub would fail these runs '
              f'instantly with no logs.')
        return 1
    print('workflows OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
