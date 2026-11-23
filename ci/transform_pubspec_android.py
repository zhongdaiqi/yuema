#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CI 专用：把 yuema 的本地 path 依赖转换成可在 GitHub Linux runner 上解析的形式，
并就地打补丁让 Android 能编译通过（仅作用于 CI 的临时 checkout，不触碰本地鸿蒙源码）。

本仓库的 pubspec.yaml 在 Windows/鸿蒙开发环境下，把若干插件写成了
本地绝对路径依赖（F:/flutter_ohos/*），这些路径在 GitHub 的 Linux runner 上
不存在，flutter pub get 会直接失败。

本脚本做三件事（与 transform_pubspec_ios.py 同源，去掉 iOS 专用的 pbxproj 注入）：
  1. 转换 pubspec.yaml：
     - 所有 F:/ 的 path 依赖 -> 去掉本地路径（pub.dev 自动解析兼容版本）
     - 删除鸿蒙专用的 dependency_overrides 整段（那些路径 CI 上不存在）
  2. 写一份 Android 专用 OhosView 占位类到 lib/_android_ci_ohos_view_stub.dart。
     标准 Flutter 没有 OhosView（鸿蒙 Flutter 分支独有），不补占位类 Android
     编译期就会报「未定义 OhosView」。本地鸿蒙构建不跑本脚本，不受影响。
  3. 移除 device_id_service.dart 中的鸿蒙专用分支（OhosDeviceInfo / ohosInfo）：
     官方 device_info_plus 没有该类型与 getter，Dart AOT 编译期报
     "'OhosDeviceInfo' isn't a type"。本地鸿蒙构建不跑本脚本，不受影响。

仅应在 CI 上运行；不要在本地 Windows 开发机执行，否则破坏本地鸿蒙 path 依赖。
"""
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
PUBSPEC = os.path.join(REPO_ROOT, "pubspec.yaml")

# Android 专用 OhosView 占位类：构造签名与鸿蒙框架一致，build 返回空
OHOS_VIEW_STUB_REL = "lib/_android_ci_ohos_view_stub.dart"
OHOS_VIEW_STUB_IMPORT = "import 'package:yuema/_android_ci_ohos_view_stub.dart';"

OHOS_VIEW_STUB_CONTENT = """// Android/CI 专用占位：标准 Flutter 没有 OhosView（它是鸿蒙 Flutter 分支独有类）。
// CI 转换脚本会把这个文件写入 lib/ 并向 huawei 视图文件注入 import，
// 仅用于让 Android 编译通过；本地鸿蒙构建不跑转换脚本，框架自带 OhosView，不受影响。
import 'package:flutter/widgets.dart';

class OhosView extends StatelessWidget {
  final String viewType;
  final dynamic onPlatformViewCreated;
  final dynamic creationParams;
  final dynamic creationParamsCodec;
  final dynamic gestureRecognizers;
  final dynamic hitTestBehavior;
  final dynamic layoutDirection;

  const OhosView({
    super.key,
    required this.viewType,
    this.onPlatformViewCreated,
    this.creationParams,
    this.creationParamsCodec,
    this.gestureRecognizers,
    this.hitTestBehavior,
    this.layoutDirection,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
"""

# 引用了 OhosView 的文件（相对仓库根），需注入占位类 import
OHOS_VIEW_FILES = [
    "lib/screens/huawei_login_page.dart",
    "lib/screens/huawei_login_view.dart",
]

# 鸿蒙专用设备信息分支：官方 device_info_plus 无 OhosDeviceInfo 类型 / ohosInfo getter，
# Android AOT 编译期会报 "'OhosDeviceInfo' isn't a type"。CI 上整段替换为等价的
# 「跳过」注释；该 try/catch 本来就有 catch 兜底，Android 上进入也会立即抛异常被吞掉，
# 移除后行为一致（后续 androidInfo/iosInfo 分支照常执行）。
DEVICE_INFO_REL = "lib/services/device_id_service.dart"
OHOS_INFO_BLOCK_START = "      // 首先尝试鸿蒙系统专用API"
OHOS_INFO_BLOCK_END = "        print('无法获取鸿蒙设备信息: $e');\n      }"
OHOS_INFO_BLOCK_REPLACEMENT = (
    "      // Android/CI 转换：官方 device_info_plus 无鸿蒙 API，跳过该分支（本地鸿蒙构建不跑本脚本）"
)


def transform_pubspec() -> int:
    if not os.path.isfile(PUBSPEC):
        print(f"::error::找不到 {PUBSPEC}", file=sys.stderr)
        return 1

    lines = open(PUBSPEC, encoding="utf-8").read().split("\n")
    out = []
    in_overrides = False
    i = 0
    n = len(lines)
    converted = 0
    removed_overrides = 0

    while i < n:
        line = lines[i]
        stripped = line.strip()

        if stripped == "dependency_overrides:" and not in_overrides:
            in_overrides = True
            i += 1
            continue

        if in_overrides:
            if line and not (line[0] in (" ", "\t")):
                in_overrides = False
            else:
                removed_overrides += 1
                i += 1
                continue

        # 检测 path 依赖：name:\n  path: ...
        m = re.match(r"^(\s*)([A-Za-z0-9_]+):\s*$", line)
        if m:
            indent = m.group(1)
            name = m.group(2)
            j = i + 1
            while j < n and lines[j].strip() == "":
                j += 1
            if j < n and lines[j].strip().startswith("path:"):
                # 去掉本地 path，变成无版本约束（pub.dev 自动解析兼容版本）
                out.append(f"{indent}{name}:")
                converted += 1
                i = j + 1
                continue

        out.append(line)
        i += 1

    open(PUBSPEC, "w", encoding="utf-8").write("\n".join(out))
    print(
        f"transform_pubspec: converted_path_deps={converted}, "
        f"removed_override_lines={removed_overrides}"
    )
    return 0


def patch_ohos_views() -> int:
    stub_path = os.path.join(REPO_ROOT, OHOS_VIEW_STUB_REL)
    open(stub_path, "w", encoding="utf-8").write(OHOS_VIEW_STUB_CONTENT)

    patched = 0
    for rel in OHOS_VIEW_FILES:
        fpath = os.path.join(REPO_ROOT, rel)
        if not os.path.isfile(fpath):
            print(f"::warning::找不到 {rel}，跳过 OhosView 补丁")
            continue
        content = open(fpath, encoding="utf-8").read()
        if OHOS_VIEW_STUB_IMPORT in content:
            continue
        marker = "import 'package:flutter/material.dart';"
        if marker not in content:
            print(f"::warning::{rel} 未找到 {marker}，跳过")
            continue
        content = content.replace(marker, f"{marker}\n{OHOS_VIEW_STUB_IMPORT}", 1)
        open(fpath, "w", encoding="utf-8").write(content)
        patched += 1

    print(f"patch_ohos_views: wrote_stub=1, patched_files={patched}")
    return 0


def patch_ohos_device_info() -> int:
    """移除 device_id_service.dart 中的鸿蒙专用分支（仅 CI checkout）。"""
    fpath = os.path.join(REPO_ROOT, DEVICE_INFO_REL)
    if not os.path.isfile(fpath):
        print(f"::warning::找不到 {DEVICE_INFO_REL}，跳过 OhosDeviceInfo 补丁")
        return 0
    content = open(fpath, encoding="utf-8").read()
    if "OhosDeviceInfo" not in content:
        print("patch_ohos_device_info: 无 OhosDeviceInfo 引用，跳过（幂等）")
        return 0
    start = content.find(OHOS_INFO_BLOCK_START)
    end = content.find(OHOS_INFO_BLOCK_END, start + 1) if start >= 0 else -1
    if start < 0 or end < 0:
        print(f"::error::{DEVICE_INFO_REL} 找到 OhosDeviceInfo 但无法定位待移除 try 块边界", file=sys.stderr)
        return 1
    end += len(OHOS_INFO_BLOCK_END)
    content = content[:start] + OHOS_INFO_BLOCK_REPLACEMENT + content[end:]
    open(fpath, "w", encoding="utf-8").write(content)
    print("patch_ohos_device_info: removed_harmony_branch=1")
    return 0


def main() -> int:
    rc = transform_pubspec()
    if rc != 0:
        return rc
    rc = patch_ohos_device_info()
    if rc != 0:
        return rc
    patch_ohos_views()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
