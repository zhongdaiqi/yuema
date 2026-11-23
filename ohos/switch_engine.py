"""Switch libflutter.so in the flutter_native_arm64_v8a ohpm module per build mode.

Why: oh-package.json5 overrides always point to the DEBUG engine har
(arm64_v8a_debug.har), so oh_modules ships a debug-mode libflutter.so.
In debug-mode engines, TRACING_CHECKS_NECESSARY is active
(engine/src/flutter/runtime/ptrace_check.cc): nativeInit() only succeeds when
launched with --enable-checked-mode (i.e. via `flutter run`). Launching from
the home screen (hdc aa start) without that flag makes nativeInit return
non-zero -> FlutterNapi.hasInit=false -> attachToNative fails ->
"Cannot create a FlutterEngine instance in debug mode without Flutter tooling"
-> engine never created -> white screen / instant exit.

Fix: for release/profile builds, swap in the mode-specific engine .so from
bin/cache/artifacts/engine/ohos-arm64-<mode>/<arch>_<mode>.har (release engine
= 16.4MB, no JIT/DDS). The debug .so is backed up on first switch and restored
afterwards. ArkTS sources in the embedding har are mode-agnostic (verified by
diff), and BuildProfile.ets is handled by patch_buildprofile.py.

Usage: python switch_engine.py [debug|release|profile]
"""
import glob
import gzip
import io
import os
import shutil
import sys
import tarfile

MODE = (sys.argv[1] if len(sys.argv) > 1 else 'debug').strip().lower()
if MODE not in ('debug', 'release', 'profile'):
    print('switch_engine: invalid mode %r' % MODE)
    sys.exit(1)

OHOS_ROOT = r'F:/AiPro/yuema/ohos'
ENGINE_CACHE = os.path.join(OHOS_ROOT, '.engine_cache')

# flutter SDK artifacts: per-mode engine hars
ARTIFACT_BASE = r'F:/flutter_ohos/flutter_flutter/bin/cache/artifacts/engine'
HAR_BY_MODE = {
    'debug':   os.path.join(ARTIFACT_BASE, 'ohos-arm64', 'arm64_v8a_debug.har'),
    'profile': os.path.join(ARTIFACT_BASE, 'ohos-arm64-profile', 'arm64_v8a_profile.har'),
    'release': os.path.join(ARTIFACT_BASE, 'ohos-arm64-release', 'arm64_v8a_release.har'),
}


def find_module_dir():
    pats = glob.glob(
        OHOS_ROOT + '/oh_modules/.ohpm/flutter_native_arm64_v8a@*/'
        'oh_modules/flutter_native_arm64_v8a')
    if not pats:
        return None
    return pats[0]


def extract_so_from_har(har_path, dest_so):
    """Extract libs/arm64-v8a/libflutter.so from a gzip-tar .har."""
    with gzip.open(har_path, 'rb') as f:
        data = f.read()
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as tf:
        for member in tf.getmembers():
            if member.name.replace('\\', '/').endswith('libs/arm64-v8a/libflutter.so'):
                src = tf.extractfile(member)
                if src is None:
                    break
                os.makedirs(os.path.dirname(dest_so), exist_ok=True)
                with open(dest_so, 'wb') as out:
                    shutil.copyfileobj(src, out)
                return True
    return False


def main():
    mod_dir = find_module_dir()
    if mod_dir is None:
        print('switch_engine: flutter_native_arm64_v8a module not found in oh_modules')
        sys.exit(1)

    so_path = os.path.join(mod_dir, 'libs', 'arm64-v8a', 'libflutter.so')
    backup_path = os.path.join(ENGINE_CACHE, 'libflutter_debug.so')
    os.makedirs(ENGINE_CACHE, exist_ok=True)

    if MODE == 'debug':
        # restore debug engine
        if os.path.exists(backup_path):
            shutil.copyfile(backup_path, so_path)
            print('switch_engine: restored debug libflutter.so (%d bytes)'
                  % os.path.getsize(so_path))
        else:
            print('switch_engine: no backup found, current .so kept (assumed debug)')
        sys.exit(0)

    # release/profile: back up current (debug) engine once, then swap in mode engine
    if not os.path.exists(backup_path):
        shutil.copyfile(so_path, backup_path)
        print('switch_engine: backed up debug libflutter.so -> %s (%d bytes)'
              % (backup_path, os.path.getsize(backup_path)))

    har_path = HAR_BY_MODE[MODE]
    if not os.path.exists(har_path):
        print('switch_engine: engine har not found: %s' % har_path)
        sys.exit(1)

    cached_so = os.path.join(ENGINE_CACHE, 'libflutter_%s.so' % MODE)
    if not os.path.exists(cached_so):
        if not extract_so_from_har(har_path, cached_so):
            print('switch_engine: libflutter.so not found inside %s' % har_path)
            sys.exit(1)
        print('switch_engine: extracted %s engine -> %s (%d bytes)'
              % (MODE, cached_so, os.path.getsize(cached_so)))

    shutil.copyfile(cached_so, so_path)
    print('switch_engine: module now uses %s libflutter.so (%d bytes)'
          % (MODE, os.path.getsize(so_path)))
    sys.exit(0)


if __name__ == '__main__':
    main()
