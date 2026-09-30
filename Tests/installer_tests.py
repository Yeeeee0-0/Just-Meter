#!/usr/bin/env python3
"""Inspect installed payload paths and signed-byte integrity without changing /Applications."""
import hashlib
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT=pathlib.Path(__file__).resolve().parent.parent
package=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'outputs/Just-Meter-0.1.3-macOS-arm64-preview.pkg'

def files(bundle):
    return {str(p.relative_to(bundle)):hashlib.sha256(p.read_bytes()).hexdigest() for p in bundle.rglob('*') if p.is_file()}

with tempfile.TemporaryDirectory(prefix='installer-test-',dir=ROOT/'build') as temp:
    expanded=pathlib.Path(temp)/'expanded'
    subprocess.run(['pkgutil','--expand-full',str(package),str(expanded)],check=True)
    distribution=ET.parse(expanded/'Distribution').getroot()
    choices=distribution.findall('choice')
    assert {c.attrib['id'] for c in choices}=={'app','vst3'}
    assert all(c.attrib['start_selected']=='true' and 'selected' not in c.attrib for c in choices), 'Both choices should default on but remain independently editable'
    assert distribution.find('options').attrib['customize']=='always'
    assert distribution.find('options').attrib['hostArchitectures']=='arm64'
    assert distribution.find('volume-check/allowed-os-versions/os-version').attrib['min']=='26.0'
    assert distribution.find('domains').attrib['enable_localSystem']=='true'
    assert not (expanded/'Resources/Welcome.html').exists(), 'Unlocalized HTML shadows the translated pages in Installer'
    assert not (expanded/'Resources/Conclusion.html').exists()
    for language in ('en','zh-Hans'):
        localized=expanded/'Resources'/f'{language}.lproj'
        strings=subprocess.check_output(['plutil','-convert','json','-o','-',str(localized/'Localizable.strings')],text=True)
        import json
        labels=json.loads(strings)
        for choice in choices:
            assert labels[choice.attrib['title']] and labels[choice.attrib['description']]
        for name in ('Welcome.html','Conclusion.html'):
            page=(localized/name).read_text()
            assert '@VERSION@' not in page and '@STATUS@' not in page
            assert ('Standalone App' if language=='en' else '独立 App') in page
        print(f'PASS: {language} installer welcome, conclusion, choice titles and descriptions')
    for component,name,location,identifier in [('app','Just Meter.app','/Applications','studio.justmeter.app'),('vst3','Just Meter.vst3','/Library/Audio/Plug-Ins/VST3','studio.justmeter.vst3')]:
        info=ET.parse(expanded/f'{component}.pkg/PackageInfo').getroot()
        assert info.attrib['install-location']==location
        assert not (expanded/f'{component}.pkg/Scripts').exists(), 'No privileged install scripts are needed'
        assert info.attrib.get('relocatable')=='false' and info.find('relocate/bundle') is None, 'Development copies must not redirect installation'
        payload=expanded/f'{component}.pkg/Payload'/name
        source=ROOT/'outputs'/name
        assert files(payload)==files(source), 'Package extraction must preserve every signed byte'
        metadata=plistlib.loads((payload/'Contents/Info.plist').read_bytes())
        assert metadata['CFBundleIdentifier']==identifier
        assert metadata['CFBundleShortVersionString']==info.attrib['version']=='0.1.3'
        assert metadata['CFBundleVersion']=='4'
        if component=='app':
            assert metadata['CFBundleLocalizations']==['en','zh-Hans']
            for language in ('en','zh-Hans'):
                assert (payload/'Contents/Resources'/f'{language}.lproj/InfoPlist.strings').is_file()
        subprocess.run(['codesign','--verify','--deep','--strict',str(payload)],check=True)
        print(f'PASS: {component} payload, version, stable ID, destination, byte integrity, signature, no install scripts')
    print('PASS: two optional components, both selected initially; arm64/macOS requirements; fixed global installation domain')
print('Scope: package structure and extracted bundles verified; no system installation or notarization was performed by this test.')
