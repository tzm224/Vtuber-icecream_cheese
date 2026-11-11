#!/bin/bash
# Downloads a prebuilt, universal macOS app. No sudo, Xcode, Homebrew or Python.
set -euo pipefail

REPOSITORY="tzm224/Vtuber-icecream_cheese"
VERSION="${CHEESE_VERSION:-latest}"
INSTALL_DIR="${CHEESE_INSTALL_DIR:-$HOME/Applications}"
APP_NAME="CheesePet.app"
ARCHIVE="CheesePet-macOS-universal.zip"
BUNDLE_ID="io.github.tzm224.cheesepet"

fail() { printf '\n安装未完成：%s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "只支持 macOS 13 或更高版本。"
OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[[ "$OS_MAJOR" =~ ^[0-9]+$ ]] && (( OS_MAJOR >= 13 )) || fail "需要 macOS 13 或更新版本。"
case "$(uname -m)" in arm64|x86_64) ;; *) fail "不支持当前 CPU 架构。" ;; esac
case "$VERSION" in latest) BASE="https://github.com/$REPOSITORY/releases/latest/download" ;;
    v[0-9]*) [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || fail "版本号格式不正确。"
        BASE="https://github.com/$REPOSITORY/releases/download/$VERSION" ;;
    *) fail "CHEESE_VERSION 应为 latest 或 v1.0.0 这样的版本号。" ;;
esac

for command in curl shasum unzip ditto codesign plutil open; do
    command -v "$command" >/dev/null 2>&1 || fail "缺少 macOS 系统工具：$command"
done
if pgrep -x CheesePet >/dev/null 2>&1; then
    fail "雪糕正在运行。请从菜单栏 ✨ 退出桌宠，再重新执行安装命令。"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cheese-install.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
printf '正在下载雪糕cheese桌宠（%s）…\n' "$VERSION"
curl --proto '=https' --tlsv1.2 -fLS --retry 3 --connect-timeout 20 --max-time 180 \
    "$BASE/$ARCHIVE" -o "$WORK/$ARCHIVE" || fail "未能下载发布包。请检查网络，并确认仓库已有成功发布的 Release。"
curl --proto '=https' --tlsv1.2 -fLS --retry 3 --connect-timeout 20 --max-time 60 \
    "$BASE/SHA256SUMS" -o "$WORK/SHA256SUMS" || fail "未能下载校验文件。"

# Only accept the expected single checksum entry, never paths supplied by a file.
CHECKSUM="$(awk -v archive="$ARCHIVE" '$2 == archive { print $1 }' "$WORK/SHA256SUMS")"
[[ "$CHECKSUM" =~ ^[0-9a-fA-F]{64}$ ]] || fail "校验文件格式不正确。"
printf '%s  %s\n' "$CHECKSUM" "$ARCHIVE" > "$WORK/verify.txt"
(cd "$WORK" && shasum -a 256 -c verify.txt) || fail "下载文件校验失败，请稍后重试。"
unzip -Z1 "$WORK/$ARCHIVE" > "$WORK/entries.txt" || fail "发布包无法读取。"
while IFS= read -r entry; do
    case "$entry" in "$APP_NAME/"*) ;; *) fail "发布包包含意外路径。" ;; esac
    case "/$entry/" in */../*|*/./*) fail "发布包包含不安全路径。" ;; esac
done < "$WORK/entries.txt"
mkdir "$WORK/unpacked"
ditto -x -k "$WORK/$ARCHIVE" "$WORK/unpacked"
APP="$WORK/unpacked/$APP_NAME"
[[ -d "$APP" && ! -L "$APP" && -x "$APP/Contents/MacOS/CheesePet" ]] || fail "发布包缺少应用程序。"
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$APP/Contents/Info.plist")" == "$BUNDLE_ID" ]] || fail "应用标识不匹配。"
codesign --verify --deep --strict "$APP" || fail "应用完整性验证失败。"

mkdir -p "$INSTALL_DIR"
DESTINATION="$INSTALL_DIR/$APP_NAME"
BACKUP=""
if [[ -e "$DESTINATION" || -L "$DESTINATION" ]]; then
    [[ -d "$DESTINATION" && ! -L "$DESTINATION" ]] || fail "安装位置已被其他文件或链接占用：$DESTINATION"
    [[ "$(plutil -extract CFBundleIdentifier raw -o - "$DESTINATION/Contents/Info.plist" 2>/dev/null)" == "$BUNDLE_ID" ]] || fail "安装位置存在不同应用，未覆盖。"
    BACKUP_DIR="$HOME/Library/Application Support/CheesePet/Backups"
    mkdir -p "$BACKUP_DIR"
    BACKUP="$BACKUP_DIR/CheesePet-$(date +%Y%m%d-%H%M%S)-$$.app"
    mv "$DESTINATION" "$BACKUP"
fi
if ! mv "$APP" "$DESTINATION"; then
    if [[ -n "$BACKUP" ]]; then mv "$BACKUP" "$DESTINATION"; fi
    fail "无法写入安装目录，原版本已尽力保留。"
fi
printf '\n已安装到：%s\n' "$DESTINATION"
if [[ -n "$BACKUP" ]]; then printf '旧版本已备份到：%s\n' "$BACKUP"; fi
if open "$DESTINATION"; then
    printf '雪糕来啦！单击打招呼，双击跳跃，拖动移动；菜单栏 ✨ 可退出或设置。\n'
else
    printf '应用已安装，但系统没有打开它。请在 Finder 打开应用，并按 macOS 的安全提示处理。\n' >&2
    exit 1
fi
