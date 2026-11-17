#!/usr/bin/env python3
"""Read-only metadata guard for a real MTaxi .app, .xcarchive or .ipa.

This does not verify a code signature or establish App Store approval.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
import sys
import zipfile


def verify(path, version, build, require_firebase=False):
    bundle = 'com.milanium.mtaxi'
    archive = None
    try:
        if path.is_file() and path.suffix == '.ipa':
            archive = zipfile.ZipFile(path)
            names = archive.namelist()
            mains = [n for n in names if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', n)]
            if len(mains) != 1:
                raise ValueError('Expected one main application in IPA')
            prefix = mains[0][:-len('Info.plist')]
            read = lambda name: plistlib.loads(archive.read(prefix + name))
            extensions = [n[len(prefix):] for n in names if n.startswith(prefix + 'PlugIns/') and n.endswith('.appex/Info.plist')]
        else:
            if path.suffix == '.xcarchive':
                mains = list((path / 'Products/Applications').glob('*.app'))
                if len(mains) != 1:
                    raise ValueError('Expected one main application in xcarchive')
                path = mains[0]
            if not path.is_dir() or path.suffix != '.app':
                raise ValueError('Provide a built .app, .xcarchive or .ipa')
            read = lambda name: plistlib.loads((path / name).read_bytes())
            extensions = [str(p.relative_to(path)) for p in (path / 'PlugIns').glob('*.appex/Info.plist')]
        main = read('Info.plist')
        if main.get('CFBundleIdentifier') != bundle:
            raise ValueError('Wrong main Bundle ID; expected MTaxi, not Taxi 24')
        for key, expected in [('CFBundleShortVersionString', version), ('CFBundleVersion', str(build))]:
            if str(main.get(key)) != expected:
                raise ValueError('Main version/build does not match the selected release')
        matched = []
        for name in extensions:
            ext = read(name)
            if ext.get('CFBundleIdentifier') != bundle + '.ImageNotification':
                continue
            for key in ['CFBundleShortVersionString', 'CFBundleVersion']:
                if str(ext.get(key)) != str(main.get(key)):
                    raise ValueError('Notification extension version/build differs from main app')
            matched.append(ext['CFBundleIdentifier'])
        if len(matched) != 1:
            raise ValueError('Expected one MTaxi ImageNotification extension')
        if require_firebase:
            firebase = read('GoogleService-Info.plist')
            if firebase.get('PROJECT_ID') != 'mtaxi-52990' or firebase.get('BUNDLE_ID') != bundle:
                raise ValueError('Firebase project or Bundle ID does not match MTaxi')
        return {'bundleId': bundle, 'version': version, 'build': str(build),
                'extensions': matched, 'firebaseChecked': require_firebase,
                'scope': 'metadata only; verify signing, entitlements and device behavior separately'}
    finally:
        if archive:
            archive.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--expected-version', required=True)
    parser.add_argument('--expected-build', required=True)
    parser.add_argument('--require-firebase', action='store_true')
    args = parser.parse_args()
    try:
        result = verify(args.archive, args.expected_version, args.expected_build, args.require_firebase)
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        print('iOS archive check failed: ' + str(error), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
