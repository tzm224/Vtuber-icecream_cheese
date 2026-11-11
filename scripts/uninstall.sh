#!/bin/bash
set -euo pipefail
APP="${CHEESE_INSTALL_DIR:-$HOME/Applications}/CheesePet.app"
[[ "$(uname -s)" == Darwin ]] || { echo "This script is for macOS." >&2; exit 1; }
if pgrep -x CheesePet >/dev/null 2>&1; then
    echo "请先从菜单栏 ✨ 退出桌宠，再卸载。" >&2
    exit 1
fi
[[ -d "$APP" && ! -L "$APP" ]] || { echo "未找到应用：$APP"; exit 0; }
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$APP/Contents/Info.plist")" == io.github.tzm224.cheesepet ]] || { echo "应用标识不匹配，未移动。" >&2; exit 1; }
mkdir -p "$HOME/.Trash"
mv "$APP" "$HOME/.Trash/CheesePet-$(date +%Y%m%d-%H%M%S)-$$.app"
echo "应用已移到废纸篓。偏好设置和旧版本备份已保留。"
