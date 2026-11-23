"""Patch BuildProfile.ets in ohpm dependency modules per build mode.

Why: hvigor's --generate-build-profile only regenerates BuildProfile.ets
for in-project modules. ohpm dependency modules (@ohos/flutter_ohos,
flutter_native_arm64_v8a) keep the har default BUILD_MODE_NAME='debug',
so release builds compile the debug code path: FlutterLoader.isDebugMode
is true -> copyResource() tries to copy kernel_blob.bin (absent in AOT
packages) -> "Invalid relative path" -> root isolate never created ->
white screen.

Usage: python patch_buildprofile.py [debug|release|profile]
"""
import glob
import re
import sys

MODE = (sys.argv[1] if len(sys.argv) > 1 else 'release').strip().lower()
if MODE not in ('debug', 'release', 'profile'):
    print('patch_buildprofile: invalid mode %r' % MODE)
    sys.exit(1)

BASE = r'F:/AiPro/yuema/ohos/oh_modules/.ohpm'
PATTERNS = [
    BASE + '/@ohos+flutter_ohos@*/oh_modules/@ohos/flutter_ohos/BuildProfile.ets',
    BASE + '/flutter_native_arm64_v8a@*/oh_modules/flutter_native_arm64_v8a/BuildProfile.ets',
]

mode_name = 'release' if MODE == 'release' else ('profile' if MODE == 'profile' else 'debug')
debug_flag = 'true' if MODE == 'debug' else 'false'

count = 0
for pat in PATTERNS:
    for path in glob.glob(pat):
        text = open(path, 'r', encoding='utf-8').read()
        text = re.sub(r"BUILD_MODE_NAME = '[^']*'",
                      "BUILD_MODE_NAME = '%s'" % mode_name, text)
        text = re.sub(r'\bDEBUG = (true|false)\b',
                      'DEBUG = %s' % debug_flag, text)
        open(path, 'w', encoding='utf-8', newline='').write(text)
        print('patch_buildprofile: %s -> mode=%s debug=%s' % (path.split('ohpm/')[-1][:60], mode_name, debug_flag))
        count += 1

print('patch_buildprofile: %d file(s) patched' % count)
sys.exit(0 if count else 1)
