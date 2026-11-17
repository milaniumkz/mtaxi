#!/usr/bin/env python3
"""Repeat the existing Flutter/backend suites against disposable test fixtures.

Never invokes deployment, a bank, production accounts or a binary build.
Logs and resumable results must live outside the repository's source tree.
"""
import argparse
import concurrent.futures
import json
import hashlib
import os
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rounds', type=int, default=30)
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.rounds <= 100 or not 1 <= args.workers <= 4:
        parser.error('rounds: 1..100; workers: 1..4')
    root = Path(__file__).resolve().parent.parent
    output = args.output.resolve()
    if output == root or root in output.parents:
        parser.error('Choose an output directory outside the repository')
    output.mkdir(parents=True, exist_ok=True)
    commands = {
        'flutter': ['flutter', 'test', '--no-pub', '--concurrency=2'],
        'server': ['npm', 'test', '--prefix', 'server'],
    }
    env = dict(os.environ, MTAXI_FCM_ENABLED='false', CI='true', DART_SUPPRESS_ANALYTICS='true')

    def fingerprint():
        names = subprocess.check_output(
            ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root
        ).decode().split('\0')
        digest = hashlib.sha256()
        for name in sorted(set(names)):
            if not name or name.startswith('test/failures/'):
                continue
            if name not in ('pubspec.yaml', 'pubspec.lock') and not name.startswith(
                ('lib/', 'server/', 'scripts/', 'deploy/', 'test/', '.github/workflows/', 'assets/fonts/')
            ):
                continue
            file = root / name
            if file.is_file():
                digest.update(name.encode())
                digest.update(file.read_bytes())
        return digest.hexdigest()

    def run(kind, number):
        source_fingerprint = fingerprint()
        result_path = output / f'{kind}-{number:02}.json'
        if result_path.exists():
            previous = json.loads(result_path.read_text())
            if previous.get('returncode') == 0 and previous.get('source_fingerprint') == source_fingerprint:
                return previous
        started = time.monotonic()
        log_path = output / f'{kind}-{number:02}.log'
        try:
            with log_path.open('w') as log:
                code = subprocess.run(commands[kind], cwd=root, env=env,
                                      stdout=log, stderr=subprocess.STDOUT, timeout=300).returncode
        except subprocess.TimeoutExpired:
            code = 124
        if fingerprint() != source_fingerprint:
            code = 125  # Source changed: this run cannot certify the final revision.
        result = {'suite': kind, 'round': number, 'returncode': code,
                  'source_fingerprint': source_fingerprint,
                  'seconds': round(time.monotonic()-started, 2), 'log': str(log_path)}
        result_path.write_text(json.dumps(result, indent=2)+'\n')
        return result

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(run, kind, number)
                   for number in range(1, args.rounds+1) for kind in commands]
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            results.append(result)
            print(f"{result['suite']} {result['round']}/{args.rounds}: "
                  f"{'PASS' if result['returncode']==0 else 'FAIL'} ({result['seconds']}s)", flush=True)
            summary = {'requested_rounds': args.rounds, 'completed': len(results),
                       'passed': sum(r['returncode']==0 for r in results),
                       'results': sorted(results, key=lambda r: (r['suite'], r['round']))}
            (output/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    return 0 if all(r['returncode']==0 for r in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
