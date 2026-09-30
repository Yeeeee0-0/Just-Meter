import pathlib, plistlib, subprocess, struct, shutil
root=pathlib.Path(__file__).resolve().parent.parent
app=root/'outputs/Just Meter.app'
info={
 'CFBundleName':'Just Meter','CFBundleDisplayName':'Just Meter',
 'CFBundleIdentifier':'studio.justmeter.app','CFBundleVersion':'4',
 'CFBundleShortVersionString':'0.1.3','CFBundleExecutable':'JustMeter',
 'CFBundlePackageType':'APPL','CFBundleIconFile':'AppIcon',
 'CFBundleDevelopmentRegion':'en','CFBundleLocalizations':['en','zh-Hans'],
 'NSHighResolutionCapable':True,'LSMinimumSystemVersion':'26.0',
 'NSMicrophoneUsageDescription':'Just Meter 读取所选音频输入，仅在本机计算频谱和响度。',
 'NSAudioCaptureUsageDescription':'Just Meter 读取系统播放的音频，仅在本机计算频谱和响度。',
 'CFBundleDocumentTypes':[{'CFBundleTypeName':'Audio','CFBundleTypeRole':'Viewer','LSHandlerRank':'Alternate','LSItemContentTypes':['public.audio']}],
}
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
for localization in (root/'Sources/App/Resources').glob('*.lproj'):
 shutil.copytree(localization,app/'Contents/Resources'/localization.name,dirs_exist_ok=True)
licenses=app/'Contents/Resources/Licenses';licenses.mkdir(exist_ok=True)
shutil.copy2(root/'vendor/libebur128/COPYING',licenses/'libebur128-MIT.txt')
shutil.copy2(root/'LICENSE',licenses/'Just-Meter-MIT.txt')
iconset=root/'build/AppIcon.iconset';iconset.mkdir(exist_ok=True)
for size in [16,32,128,256,512]:
 for scale in [1,2]:
  output=iconset/f'icon_{size}x{size}{"@2x" if scale==2 else ""}.png'
  subprocess.run(['sips','-z',str(size*scale),str(size*scale),str(root/'Sources/App/Resources/AppIcon.png'),'--out',str(output)],check=True,stdout=subprocess.DEVNULL)
chunks=[]
for code,name in [('icp4','16x16'),('icp5','32x32'),('ic07','128x128'),('ic08','256x256'),('ic09','512x512'),('ic10','512x512@2x'),('ic11','16x16@2x'),('ic12','32x32@2x'),('ic13','128x128@2x'),('ic14','256x256@2x')]:
 data=(iconset/f'icon_{name}.png').read_bytes();chunks.append(code.encode()+struct.pack('>I',len(data)+8)+data)
data=b''.join(chunks)
(app/'Contents/Resources/AppIcon.icns').write_bytes(b'icns'+struct.pack('>I',len(data)+8)+data)
