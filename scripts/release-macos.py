#!/usr/bin/env python3
"""Sign, notarize and staple a selectable installer. Requires real Developer ID identities."""
import argparse
import importlib.util
import json
import pathlib
import plistlib
import re
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent

def run(*args, capture=False):
    return subprocess.run([str(a) for a in args], check=True, text=True,
                          stdout=subprocess.PIPE if capture else None,
                          stderr=subprocess.PIPE if capture else None)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--application-identity', required=True, help='Developer ID Application certificate name')
    parser.add_argument('--installer-identity', required=True, help='Developer ID Installer certificate name')
    parser.add_argument('--notary-profile', required=True, help='Name of credentials already stored with notarytool in your Keychain')
    args = parser.parse_args()
    for value, prefix in [(args.application_identity, 'Developer ID Application:'), (args.installer_identity, 'Developer ID Installer:')]:
        if not value.startswith(prefix):
            parser.error(f'Expected {prefix} certificate; local/ad-hoc signing cannot be used for release')
    available = run('security', 'find-identity', '-v', capture=True).stdout
    for identity in (args.application_identity, args.installer_identity):
        if f'"{identity}"' not in available:
            parser.error(f'No valid identity/private key is available in this Mac’s Keychain: {identity}')
    teams = [re.search(r'\(([A-Z0-9]+)\)$', identity) for identity in (args.application_identity,args.installer_identity)]
    if not all(teams) or teams[0][1] != teams[1][1]:
        parser.error('Application and Installer identities must belong to the same Apple team')
    source = ROOT/'outputs'
    version = plistlib.loads((source/'Just Meter.app/Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
    work = pathlib.Path(tempfile.mkdtemp(prefix='official-release-',dir=ROOT/'build'))
    print(f'Release staging and logs: {work}', flush=True)
    for name in ('Just Meter.app', 'Just Meter.vst3'):
        bundle = work/name
        run('ditto', source/name, bundle)
        # Inside-out signing: all embedded dylibs first, then the enclosing code bundle.
        for library in sorted((bundle/'Contents/Frameworks').glob('*.dylib')):
            run('codesign','--force','--sign',args.application_identity,'--timestamp',library)
        command = ['codesign','--force','--sign',args.application_identity,'--options','runtime','--timestamp']
        if name.endswith('.app'):
            command.extend(['--entitlements', ROOT/'Installer/App.entitlements'])
        run(*command,bundle)
        run('codesign','--verify','--deep','--strict',bundle)
    spec = importlib.util.spec_from_file_location('installer_builder',ROOT/'scripts/build-installer.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    package = work/f'Just-Meter-{version}-macOS-arm64.pkg'
    module.build(work, package, args.installer_identity)
    result = run('xcrun','notarytool','submit',package,'--keychain-profile',args.notary_profile,'--wait','--output-format','json',capture=True)
    (work/'notary-result.json').write_text(result.stdout)
    submission = json.loads(result.stdout)
    if submission.get('id'):
        log = run('xcrun','notarytool','log',submission['id'],'--keychain-profile',args.notary_profile,capture=True)
        (work/'notary-log.json').write_text(log.stdout)
    if submission.get('status') != 'Accepted':
        raise SystemExit('Apple did not accept this build. No release artifact was copied to outputs; inspect the notary log.')
    run('xcrun','stapler','staple',package)
    run('xcrun','stapler','validate',package)
    run('pkgutil','--check-signature',package)
    run('spctl','--assess','--type','install','--verbose=2',package)
    # Publishable filename exists only after all release checks succeed.
    destination = source/package.name
    shutil.copy2(package,destination)
    print(f'Notarized and stapled package: {destination}')
    print('Next: download this exact package on a clean Mac and verify installation and DAW scanning before public release.')

if __name__ == '__main__':
    main()
