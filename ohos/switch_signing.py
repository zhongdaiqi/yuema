"""Switch app.products[0].signingConfig in build-profile.json5.

Usage: python switch_signing.py [debug|release]
- debug   : debug certificate + profile (hdc-installable on real device)
- release : tsy release certificate (AppGallery distribution only)
"""
import json
import sys

TARGET = (sys.argv[1] if len(sys.argv) > 1 else 'release').strip().lower()
if TARGET not in ('debug', 'release'):
    print('switch_signing: invalid target %r (use debug|release)' % TARGET)
    sys.exit(1)

# signingConfigs declares exactly two entries: "default" (tsy release cert,
# AppGallery distribution) and "debug" (debug cert, hdc-installable).
# There is NO entry named "release" - writing that literal leaves the product
# pointing at a config that does not exist, and hvigor then silently emits an
# UNSIGNED app instead of failing. Map release -> "default".
CONFIG_NAME = {'debug': 'debug', 'release': 'default'}

PATH = r'F:/AiPro/yuema/ohos/build-profile.json5'
with open(PATH, 'r', encoding='utf-8') as f:
    cfg = json.load(f)

current = cfg['app']['products'][0].get('signingConfig')
cfg['app']['products'][0]['signingConfig'] = CONFIG_NAME[TARGET]

with open(PATH, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print('switch_signing: %s -> %s' % (current, CONFIG_NAME[TARGET]))
