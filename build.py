"""Build the standalone Apple Silicon 8BitDo 85HA Keyboard app. No V2 installation needed."""
from pathlib import Path
import argparse, plistlib, shutil, subprocess, tarfile

here=Path(__file__).resolve().parent
src=here/'src'
work=here/'.build'
work.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser();parser.add_argument('--replace',action='store_true');args=parser.parse_args()
target=here/'8BitDo 85HA Keyboard.app'
identifier='local.8bitdo.85ha-keyboard'
if target.exists():
    old=plistlib.loads((target/'Contents/Info.plist').read_bytes())
    if not args.replace or old.get('CFBundleIdentifier')!=identifier:raise SystemExit('Output exists. Use --replace for an existing editor build.')
def run(command,**kwargs):subprocess.run(command,check=True,**kwargs)
usbwork=work/'libusb-build'
usb=usbwork/'libusb-1.0.29'
library=usbwork/'libusb/.libs/libusb-1.0.a'
if not library.exists():
    usbwork.mkdir(exist_ok=True)
    if not usb.exists():
        with tarfile.open(here/'third_party/libusb-1.0.29.tar.bz2') as archive:archive.extractall(usbwork,filter='data')
    run([str(usb/'configure'),'--disable-shared','--enable-static','--disable-examples-build','--disable-tests-build'],cwd=usbwork)
    run(['make','-j4'],cwd=usbwork)
    library=usbwork/'libusb/.libs/libusb-1.0.a'
run(['clang','-Wall','-Wextra','-Werror','-O2','-I',str(usb/'libusb'),str(src/'Writer.c'),str(library),'-framework','IOKit','-framework','CoreFoundation','-framework','Security','-lobjc','-o',str(work/'85HAWriter')])
run(['clang','-Wall','-Wextra','-Werror','-O2','-I',str(usb/'libusb'),str(src/'MacroWriter.c'),str(library),'-framework','IOKit','-framework','CoreFoundation','-framework','Security','-lobjc','-o',str(work/'85HAMacroWriter')])
run(['clang','-fobjc-arc','-fblocks','-Wall','-Wextra','-Werror','-O2',str(src/'Main.m'),str(src/'Editor.m'),str(src/'Device.m'),'-framework','AppKit','-framework','IOKit','-o',str(work/'85HAKeyboard')])
run(['clang','-fobjc-arc','-fblocks','-Wall','-Wextra','-Werror',str(src/'Tests.m'),str(src/'Device.m'),'-framework','AppKit','-framework','IOKit','-o',str(work/'tests')])
run([str(work/'tests')])
staging=work/'staging.app'
if staging.exists():shutil.rmtree(staging)
for folder in ['MacOS','Resources','Helpers']:(staging/'Contents'/folder).mkdir(parents=True,exist_ok=True)
shutil.copy2(work/'85HAKeyboard',staging/'Contents/MacOS/85HAKeyboard')
shutil.copy2(work/'85HAWriter',staging/'Contents/Helpers/85HAWriter')
shutil.copy2(work/'85HAMacroWriter',staging/'Contents/Helpers/85HAMacroWriter')
info=dict(CFBundleIdentifier=identifier,CFBundleName='8BitDo 85HA Keyboard',CFBundleDisplayName='8BitDo 85HA Keyboard',CFBundleExecutable='85HAKeyboard',CFBundleIconFile='AppIcon',CFBundlePackageType='APPL',CFBundleShortVersionString='0.2.0',CFBundleVersion='2',LSMinimumSystemVersion='13.0',NSHighResolutionCapable=True,NSPrincipalClass='NSApplication',NSHumanReadableCopyright='Local experimental editor for the 8BitDo 85HA. Not affiliated with 8BitDo.')
(staging/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
shutil.copy2(here/'assets/AppIcon.icns',staging/'Contents/Resources/AppIcon.icns')
shutil.copy2(src/'DemoProfile.json',staging/'Contents/Resources/DemoProfile.json')
shutil.copy2(here/'third_party/COPYING-libusb',staging/'Contents/Resources/COPYING-libusb')
run(['codesign','--force','--sign','-',str(staging/'Contents/Helpers/85HAWriter')])
run(['codesign','--force','--sign','-',str(staging/'Contents/Helpers/85HAMacroWriter')])
run(['codesign','--force','--deep','--sign','-',str(staging)])
run(['codesign','--verify','--deep','--strict',str(staging)])
if target.exists():
    previous=work/'previous.app'
    if previous.exists():shutil.rmtree(previous)
    target.rename(previous)
shutil.move(staging,target)
print(target)
