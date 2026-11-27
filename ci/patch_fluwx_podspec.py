#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CI 专用（macOS runner）：在 pod install 之前修掉 fluwx 的 ios/fluwx.podspec 顶部 preamble。

## 为什么要修

fluwx 5.7.x 的 ios/fluwx.podspec 在被 CocoaPods 加载时，会先执行一段裸 ruby：

    calling_dir = File.dirname(__FILE__)
    project_dir = calling_dir.slice(0..(calling_dir.index('/.symlinks')))
    symlinks_index = calling_dir.index('/ios/.symlinks') || calling_dir.index('/.ios/.symlinks')
    flutter_project_dir = calling_dir.slice(0..symlinks_index)
    ...
    command = "ruby #{current_dir}/wechat_setup.rb ... -p #{project_dir} -n Runner.xcodeproj"
    system(command)

它假设 podspec 被加载时的路径里一定含 `/.symlinks/plugins/fluwx`，据此切片反推
Flutter 工程根目录，再调 wechat_setup.rb 去**就地改写** Runner.xcodeproj、
Info.plist、Runner.entitlements。

在本仓库的 GitHub Actions 环境里这一步必挂：Flutter 3.41 的 Podfile 流程下
`index('/.symlinks')` 取不到值，后面的 slice 直接抛错；即使侥幸算出来，
wechat_setup.rb 也会因为 Xcodeproj::Project 拿不到工程路径而 abort。
症状是 pod install 阶段报 "Must provide a project directory and project name"。

## 怎么修

把 `Pod::Spec.new do |s|` 之前的所有内容整体替换成固定的三行变量声明
（Pod::Spec 段内只用到 logging_status / scene_delegate / fluwx_subspec），
不再做任何工程改写。

工程改写由仓库里**静态提交**的配置取代，三处必须保持一致：

    ios/Runner/Info.plist          CFBundleURLSchemes -> wxff760c510b1c8b20
                                   LSApplicationQueriesSchemes -> weixin / weixinULAPI / weixinURLParamsAPI
    ios/Runner/Runner.entitlements com.apple.developer.associated-domains -> applinks:yuema.zuime.com
    pubspec.yaml                   fluwx.app_id / fluwx.ios.universal_link（单一真相，人读）

也就是说 wechat_setup.rb 会写的东西，我们已经自己写好了，而且比它更精确
（它默认还会把 NSAllowsArbitraryLoads 打开，那会破坏 Info.plist 里按域名声明的 ATS 例外）。

## 使用

必须在 `flutter pub get` 之后、`flutter build ios`（内部触发 pod install）之前运行：

    python3 ci/patch_fluwx_podspec.py

幂等：重复执行会因为检测到 marker 而跳过。
"""
import glob
import json
import os
import re
import sys
from urllib.parse import urlparse
from urllib.request import url2pathname

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)

MARKER = "# === PREAMBLE PATCHED BY ci/patch_fluwx_podspec.py (do not edit in CI) ==="

FIXED_PREAMBLE = """# 原 preamble 用 '/.symlinks' 反推 Flutter 工程根目录，再调 wechat_setup.rb 改写
# Runner.xcodeproj / Info.plist / Runner.entitlements。CI 的 Pods 目录结构下推不出来，
# 会直接 abort。本仓库已把微信 iOS 配置静态提交（Info.plist 的 URL scheme 与
# LSApplicationQueriesSchemes、Runner.entitlements 的 associated-domains），
# 因此这里只保留 Pod::Spec 段真正会用到的三个变量。
logging_status = 'WECHAT_LOGGING=0'
scene_delegate  = ''
fluwx_subspec   = 'pay'
"""

SPEC_ANCHOR = "Pod::Spec.new do |s|"


def _uri_to_path(uri: str) -> str:
    """把 package_config 里的 rootUri 转成本机路径。

    pub 写出来的是 file:// URI（macOS/Linux 形如 file:///Users/x/.pub-cache/...，
    Windows 形如 file:///F:/...）。直接字符串切片会把 Windows 盘符搞坏成
    '/F:/...'，url2pathname 再加一层反斜杠，所以这里统一走 urlparse。
    """
    if uri.startswith("file:"):
        path = url2pathname(urlparse(uri).path)
        # Windows: url2pathname '/F:/x' -> '\F:\x'，去掉盘符前的多余分隔符
        if os.name == "nt" and re.match(r"^\\[A-Za-z]:", path):
            path = path[1:]
        return path
    # 相对 URI 相对 .dart_tool/ 解析
    return os.path.normpath(os.path.join(REPO_ROOT, ".dart_tool", uri))


def _candidate_podspecs():
    """按优先级产出可能的 fluwx podspec 路径。"""
    # 1) 首选 .dart_tool/package_config.json（最准确，pub get 一定会写）
    pkg_cfg = os.path.join(REPO_ROOT, ".dart_tool", "package_config.json")
    if os.path.isfile(pkg_cfg):
        try:
            data = json.load(open(pkg_cfg, encoding="utf-8"))
            for pkg in data.get("packages", []):
                if pkg.get("name") != "fluwx":
                    continue
                root = _uri_to_path(pkg.get("rootUri", ""))
                yield os.path.join(root, "ios", "fluwx.podspec")
        except Exception as exc:  # noqa: BLE001
            print(f"::warning::解析 package_config.json 失败：{exc}")

    # 2) 兜底：直接扫 pub 缓存（pub.dev 与国内镜像两种目录都覆盖）
    home = os.path.expanduser("~")
    patterns = [
        os.path.join(home, ".pub-cache", "hosted", "*", "fluwx-*", "ios", "fluwx.podspec"),
        os.path.join(os.environ.get("PUB_CACHE", ""), "hosted", "*", "fluwx-*", "ios", "fluwx.podspec")
        if os.environ.get("PUB_CACHE")
        else "",
        os.path.join(REPO_ROOT, "ios", ".symlinks", "plugins", "fluwx", "ios", "fluwx.podspec"),
    ]
    for pat in patterns:
        if not pat:
            continue
        for path in sorted(glob.glob(pat), reverse=True):
            yield path


def find_podspec():
    seen = set()
    for path in _candidate_podspecs():
        if not path or path in seen:
            continue
        seen.add(path)
        if os.path.isfile(path):
            return path
    return None


def main() -> int:
    podspec = find_podspec()
    if not podspec:
        print(
            "::error::找不到 fluwx 的 ios/fluwx.podspec。"
            "请确认 flutter pub get 已执行，且 pubspec 中 fluwx 已解析为 pub.dev 版本。",
            file=sys.stderr,
        )
        return 1

    src = open(podspec, encoding="utf-8").read()
    if MARKER in src:
        print(f"patch_fluwx_podspec: 已打过补丁，跳过 —— {podspec}")
        return 0

    idx = src.find(SPEC_ANCHOR)
    if idx < 0:
        print(
            f"::error::{podspec} 中找不到锚点 '{SPEC_ANCHOR}'，"
            "fluwx 版本结构可能已变，请人工核对。",
            file=sys.stderr,
        )
        return 1

    tail = src[idx:]
    # 保险：尾部仍应包含 SDK 依赖，否则说明锚点找错了位置
    if "WechatOpenSDK-XCFramework" not in tail:
        print(
            f"::error::{podspec} 锚点之后缺少 WechatOpenSDK-XCFramework 依赖，"
            "疑似结构变更，已中止以免产出不可用 pod。",
            file=sys.stderr,
        )
        return 1

    open(podspec, "w", encoding="utf-8").write(
        MARKER + "\n" + FIXED_PREAMBLE + "\n" + tail
    )
    removed_lines = src[:idx].count("\n")
    print(
        f"patch_fluwx_podspec: 已替换 preamble（丢弃 {removed_lines} 行）—— {podspec}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
