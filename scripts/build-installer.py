#!/usr/bin/env python3
"""Create a selectable, fixed-location macOS product archive; no install scripts."""
import argparse
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
COMPONENTS = (
    ('app', 'Just Meter.app', '/Applications', 'studio.justmeter.pkg.app', 'APP_TITLE', 'APP_DESCRIPTION'),
    ('vst3', 'Just Meter.vst3', '/Library/Audio/Plug-Ins/VST3', 'studio.justmeter.pkg.vst3', 'VST3_TITLE', 'VST3_DESCRIPTION'),
)

def run(*args):
    subprocess.run([str(a) for a in args], check=True)

def build(source, destination, signing_identity=None):
    info = plistlib.loads((source / 'Just Meter.app/Contents/Info.plist').read_bytes())
    version = info['CFBundleShortVersionString']
    for _, name, *_ in COMPONENTS:
        run('codesign', '--verify', '--deep', '--strict', source / name)
    (ROOT / 'build').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='installer-', dir=ROOT/'build') as temp:
        work = pathlib.Path(temp)
        packages = []
        for choice, name, location, identifier, _, _ in COMPONENTS:
            stage = work / choice
            stage.mkdir()
            run('ditto', source / name, stage / name)
            components = work / f'{choice}.plist'
            run('pkgbuild', '--analyze', '--root', stage, components)
            items = plistlib.loads(components.read_bytes())
            for item in items:
                item.update(BundleIsRelocatable=False, BundleIsVersionChecked=True,
                            BundleHasStrictIdentifier=True, BundleOverwriteAction='upgrade')
            components.write_bytes(plistlib.dumps(items))
            package = work / f'{choice}.pkg'
            run('pkgbuild', '--root', stage, '--component-plist', components,
                '--identifier', identifier, '--version', version,
                '--install-location', location, '--ownership', 'recommended', package)
            packages.append(package)
        requirements = work / 'Requirements.plist'
        requirements.write_bytes(plistlib.dumps({'os':['26.0'], 'arch':['arm64']}))
        distribution = work / 'Distribution.xml'
        command = ['productbuild', '--synthesize', '--product', requirements]
        for package in packages:
            command.extend(['--package', package])
        run(*command, distribution)
        tree = ET.parse(distribution)
        root = tree.getroot()
        for child in list(root):
            if child.tag in ('choices-outline', 'choice', 'domains', 'title', 'product'):
                root.remove(child)
        ET.SubElement(root, 'title').text = f'Just Meter {version}'
        ET.SubElement(root, 'product', {'id':'studio.justmeter.installer', 'version':version})
        ET.SubElement(root, 'domains', {'enable_localSystem':'true', 'enable_currentUserHome':'false', 'enable_anywhere':'false'})
        options = root.find('options')
        if options is None:
            options = ET.SubElement(root, 'options')
        options.set('customize', 'always')
        options.set('require-scripts', 'false')
        options.set('hostArchitectures', 'arm64')
        ET.SubElement(root, 'welcome', {'file':'Welcome.html', 'mime-type':'text/html'})
        ET.SubElement(root, 'conclusion', {'file':'Conclusion.html', 'mime-type':'text/html'})
        outline = ET.SubElement(root, 'choices-outline')
        for choice, name, location, identifier, title, detail in COMPONENTS:
            ET.SubElement(outline, 'line', {'choice':choice})
            item = ET.SubElement(root, 'choice', {'id':choice, 'title':title, 'description':detail, 'start_selected':'true', 'start_enabled':'true', 'start_visible':'true'})
            ET.SubElement(item, 'pkg-ref', {'id':identifier})
        # A package payload remains at its documented location, even when the
        # user has other development copies with the same bundle identifier.
        tree.write(distribution, encoding='utf-8', xml_declaration=True)
        resources = work / 'Resources'
        resources.mkdir()
        status = {
            'zh': ('已使用 Developer ID 签名；是否完成 Apple 公证以最终发布验收为准。' if signing_identity else
                   '开发预览安装包：尚未进行 Developer ID 正式签名与 Apple 公证，暂不适合面向普通用户分发。'),
            'en': ('Signed with Developer ID. Apple notarization is confirmed during final release validation.' if signing_identity else
                   'Development preview: not yet signed with Developer ID or notarized by Apple. Not ready for general public distribution.')
        }
        templates = ROOT/'Installer/Resources'
        for template in templates.rglob('*'):
            if not template.is_file():
                continue
            relative = template.relative_to(templates)
            destination_resource = resources/relative
            destination_resource.parent.mkdir(parents=True, exist_ok=True)
            language = 'zh' if relative.parts[0].startswith('zh') else 'en'
            destination_resource.write_text(template.read_text().replace('@VERSION@',version).replace('@STATUS@',status[language]))
        destination.parent.mkdir(parents=True, exist_ok=True)
        command = ['productbuild', '--distribution', distribution, '--resources', resources, '--package-path', work]
        if signing_identity:
            command.extend(['--sign', signing_identity, '--timestamp'])
        run(*command, destination)
        shutil.copy2(distribution, ROOT/'build/installer-distribution.xml')
    return destination

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=pathlib.Path, default=ROOT/'outputs')
    parser.add_argument('--output', type=pathlib.Path)
    parser.add_argument('--installer-identity', help='Exact Developer ID Installer certificate name; never a password')
    args = parser.parse_args()
    if args.installer_identity and not args.installer_identity.startswith('Developer ID Installer:'):
        parser.error('正式安装包必须使用 Developer ID Installer 证书')
    metadata = plistlib.loads((args.source/'Just Meter.app/Contents/Info.plist').read_bytes())
    version = metadata['CFBundleShortVersionString']
    suffix = '' if args.installer_identity else '-preview'
    output = args.output or ROOT/f'outputs/Just-Meter-{version}-macOS-arm64{suffix}.pkg'
    print(build(args.source.resolve(), output.resolve(), args.installer_identity))
