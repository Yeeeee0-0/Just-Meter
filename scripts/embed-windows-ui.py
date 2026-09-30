#!/usr/bin/env python3
"""Bundle the offline Windows UI and approved icon into native resources."""
import json
import re
import sys
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent.parent
dest = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'build/windows-ui'
dest.mkdir(parents=True, exist_ok=True)
source = (root / 'Sources/UI/Localization.swift').read_text(encoding='utf-8')
pair = re.compile(r'("(?:[^"\\]|\\.)*")\s*:\s*("(?:[^"\\]|\\.)*")')
translations = {json.loads(k): json.loads(v) for k, v in pair.findall(source)}
translations.update({
    '跟随 Windows，或选择固定的浅色与深色外观。': 'Follow Windows or choose a light or dark appearance.',
    '高对比度模式下自动使用实色背景。': 'Use solid backgrounds in high contrast mode.',
    '跟随 Windows': 'Follows Windows',
    '音频连接失败，请重新选择来源': 'Audio connection failed. Select the source again.',
    '等待宿主音频': 'Waiting for host audio',
    '选择音频来源，开始测量': 'Choose an audio source to start measuring',
    '音频设备不可用或被其他程序独占。': 'The audio device is unavailable or in exclusive use.',
})
web = root / 'Sources/Windows/Web'
html = (web / 'index.html').read_text(encoding='utf-8')
for key, content in {
    'STYLE': (web / 'style.css').read_text(encoding='utf-8'),
    'TRANSLATIONS': 'const JMTranslations=' + json.dumps(translations, ensure_ascii=False) + ';',
    'MODEL': (web / 'model.js').read_text(encoding='utf-8'),
    'APP': (web / 'app.js').read_text(encoding='utf-8'),
}.items():
    html = html.replace('/*__' + key + '__*/', content)
assert '/*__' not in html
(dest / 'MeterWeb.html').write_text(html, encoding='utf-8')
with Image.open(root / 'Sources/App/Resources/AppIcon.png') as icon:
    icon.convert('RGBA').save(dest / 'JustMeter.ico', sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
print(f'Embedded {len(translations)} translations and Windows icon in {dest}')
