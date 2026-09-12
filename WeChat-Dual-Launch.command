#!/bin/zsh

set -euo pipefail

# Select once per run; all operations below share the same implementation.
printf '%s\n' '微信双开 / WeChat Dual Launch' '1. 中文（默认）' '2. English'
printf '%s' '选择语言 / Choose language [1/2]: '
read -r UI_LANGUAGE
[[ "$UI_LANGUAGE" == "2" ]] || UI_LANGUAGE="1"

localize() {
  if [[ "$UI_LANGUAGE" == "2" ]]; then
    builtin printf '%s' "$1"
  else
    builtin printf '%s' "$2"
  fi
}

SOURCE_APP="/Applications/WeChat.app"
CLONE_APP="/Applications/WeChat2.app"
CLONE_BUNDLE_ID="com.tencent.xinWeChat2"
CLONE_DATA_DIR="$HOME/Library/Containers/com.tencent.xinWeChat2"
SCRIPT_DIR="${0:A:h}"
CUSTOM_ICON_DIR="$SCRIPT_DIR/wechat_icons"
BUILD_DIR=""
BUILD_APP=""
BACKUP_APP=""
CLONE_PROCESS_PATTERN='^/Applications/WeChat2\.app/Contents/MacOS/WeChat( |$)'
SOURCE_PROCESS_PATTERN='^/Applications/WeChat\.app/Contents/MacOS/WeChat( |$)'

blue() {
  printf '\033[1;34m%s\033[0m\n' "$1"
}

green() {
  printf '\033[1;32m%s\033[0m\n' "$1"
}

yellow() {
  printf '\033[1;33m%s\033[0m\n' "$1"
}

red() {
  printf '\033[1;31m%s\033[0m\n' "$1" >&2
}

pause_before_close() {
  printf "$(localize '\nPress Return to close...' '\n按回车键关闭窗口…')"
  read -r _unused
}

cleanup() {
  if [[ -n "${BUILD_DIR:-}" && "$BUILD_DIR" == /Applications/.wechat2-build.* && -d "$BUILD_DIR" ]]; then
    rm -rf -- "$BUILD_DIR"
  fi
}

fail() {
  red "$(localize "Failed: $1" "失败：$1")"
  if [[ -n "${BACKUP_APP:-}" ]]; then
    yellow "$(localize "The previous copy remains at: $BACKUP_APP" "旧版副本仍保存在：$BACKUP_APP")"
  fi
  pause_before_close
  exit 1
}

trap cleanup EXIT INT TERM

printf '\033c'
blue "$(localize "WeChat Dual Launch" "微信双开 / WeChat Dual Launch")"
printf '%s\n' "----------------------------------------"
printf '%s\n' "$(localize "Rebuild WeChat2.app from the installed WeChat.app." "它会从最新版 WeChat.app 重建 WeChat2.app。")"
printf '%s\n' "$(localize "Manual icon instructions will appear when finished." "完成后会显示手动更换 WeChat2.app 图标的方法。")"
printf '%s\n' "$(localize "The existing app copy will move to Trash. This data directory is preserved:" "现有副本会移到废纸篓，不会删除第二个微信的数据目录：")"
printf '  %s\n\n' "$CLONE_DATA_DIR"

if (( EUID == 0 )); then
  fail "$(localize "Double-click this script; do not run it with sudo." "请直接双击运行，不要通过 sudo 启动此脚本。")"
fi

if [[ ! -d "$SOURCE_APP" ]]; then
  fail "$(localize "Cannot find $SOURCE_APP. Install the original WeChat app first." "没有找到 $SOURCE_APP，请先安装原版微信。")"
fi

if [[ ! -w /Applications ]]; then
  fail "$(localize "Your account cannot write to /Applications. Check its permissions in Finder." "当前账户不能写入 /Applications。请在 Finder 中确认你有应用程序目录的管理权限。")"
fi

if ! codesign --verify --deep --strict "$SOURCE_APP" >/dev/null 2>&1; then
  fail "$(localize "The original app failed signature verification. Reinstall or update it first." "原版微信的代码签名校验失败，请先重新安装或更新原版微信。")"
fi

SOURCE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_APP/Contents/Info.plist" 2>/dev/null || printf "$(localize 'unknown' '未知')")
printf "$(localize 'Installed WeChat version: %s\n' '检测到原版微信版本：%s\n')" "$SOURCE_VERSION"
if [[ -d "$CLONE_APP" ]]; then
  blue "$(localize 'Existing copy: will move to Trash after verification.' '现有副本：验证新副本后移到废纸篓。')"
else
  blue "$(localize 'Existing copy: absent.' '现有副本：不存在。')"
fi
printf "$(localize '\nType y and press Return to start; anything else cancels: ' '\n输入 y 并按回车开始，输入其他内容取消：')"
read -r CONFIRMATION

if [[ "$CONFIRMATION" != "y" && "$CONFIRMATION" != "Y" ]]; then
  yellow "$(localize "Cancelled. Nothing was changed." "已取消，没有修改任何内容。")"
  pause_before_close
  exit 0
fi

blue "$(localize "[1/6] Creating a temporary build directory..." "[1/6] 创建临时构建目录…")"
BUILD_DIR=$(mktemp -d /Applications/.wechat2-build.XXXXXX)
BUILD_APP="$BUILD_DIR/WeChat2.app"

blue "$(localize "[2/6] Copying the installed WeChat app (may take a few minutes)..." "[2/6] 复制最新版微信（约需数秒至数分钟）…")"
ditto "$SOURCE_APP" "$BUILD_APP" || fail "$(localize "Could not copy WeChat." "复制微信失败。")"

blue "$(localize "[3/6] Changing the copy's Bundle ID..." "[3/6] 修改副本 Bundle ID…")"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $CLONE_BUNDLE_ID" "$BUILD_APP/Contents/Info.plist" || fail "$(localize "Could not change the Bundle ID." "修改 Bundle ID 失败。")"

ACTUAL_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUILD_APP/Contents/Info.plist")
if [[ "$ACTUAL_BUNDLE_ID" != "$CLONE_BUNDLE_ID" ]]; then
  fail "$(localize "Bundle ID verification failed." "Bundle ID 校验失败。")"
fi

blue "$(localize "[4/6] Re-signing the copy and its nested components..." "[4/6] 重新签署副本及其内部组件…")"
if ! codesign --force --deep --sign - "$BUILD_APP" >"$BUILD_DIR/codesign.log" 2>&1; then
  tail -40 "$BUILD_DIR/codesign.log" >&2
  fail "$(localize "Re-signing failed." "重新签名失败。")"
fi

blue "$(localize "[5/6] Verifying the new copy..." "[5/6] 严格验证新副本…")"
if ! codesign --verify --deep --strict --verbose=2 "$BUILD_APP" >"$BUILD_DIR/verify.log" 2>&1; then
  cat "$BUILD_DIR/verify.log" >&2
  fail "$(localize "Signature verification failed. The previous copy has not been replaced." "新副本签名验证失败。旧副本尚未被替换。")"
fi

if pgrep -f "$CLONE_PROCESS_PATTERN" >/dev/null 2>&1; then
  yellow "$(localize "Asking the running WeChat 2 to quit..." "正在退出当前运行的微信 2…")"
  osascript -e 'tell application id "com.tencent.xinWeChat2" to quit' >/dev/null 2>&1 || true

  for _attempt in {1..20}; do
    if ! pgrep -f "$CLONE_PROCESS_PATTERN" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done

  if pgrep -f "$CLONE_PROCESS_PATTERN" >/dev/null 2>&1; then
    fail "$(localize "WeChat 2 is still running. Quit it manually and run this script again." "微信 2 仍在运行。请手动退出微信 2 后重新运行脚本。")"
  fi
fi

if [[ -e "$CLONE_APP" ]]; then
  BACKUP_STAMP=$(date '+%Y%m%d-%H%M%S')
  BACKUP_APP="$HOME/.Trash/WeChat2-backup-$BACKUP_STAMP.app"

  if [[ -e "$BACKUP_APP" ]]; then
    BACKUP_APP="$HOME/.Trash/WeChat2-backup-$BACKUP_STAMP-$$.app"
  fi

  mv "$CLONE_APP" "$BACKUP_APP" || fail "$(localize "Could not move the previous copy to Trash." "无法把旧副本移到废纸篓。")"
fi

if ! mv "$BUILD_APP" "$CLONE_APP"; then
  if [[ -n "$BACKUP_APP" && -d "$BACKUP_APP" && ! -e "$CLONE_APP" ]]; then
    mv "$BACKUP_APP" "$CLONE_APP" || true
    BACKUP_APP=""
  fi
  fail "$(localize "Could not install the new copy; attempted to restore the previous copy." "无法安装新副本；已尝试恢复旧副本。")"
fi

cleanup
BUILD_DIR=""

blue "$(localize "[6/6] Starting and checking both WeChat instances..." "[6/6] 启动并检查两个微信实例…")"
open "$SOURCE_APP"
open "$CLONE_APP"
sleep 8

SOURCE_RUNNING="$(localize "no" "否")"
CLONE_RUNNING="$(localize "no" "否")"
pgrep -f "$SOURCE_PROCESS_PATTERN" >/dev/null 2>&1 && SOURCE_RUNNING="$(localize "yes" "是")"
pgrep -f "$CLONE_PROCESS_PATTERN" >/dev/null 2>&1 && CLONE_RUNNING="$(localize "yes" "是")"

printf "$(localize '\nOriginal WeChat running: %s\n' '\n原版微信运行：%s\n')" "$SOURCE_RUNNING"
printf "$(localize 'WeChat 2 running: %s\n' '微信 2 运行：%s\n')" "$CLONE_RUNNING"

if [[ "$SOURCE_RUNNING" != "$(localize "yes" "是")" || "$CLONE_RUNNING" != "$(localize "yes" "是")" ]]; then
  yellow "$(localize "The new copy is installed and verified, but two running instances were not detected." "新副本已安装且签名验证通过，但没有检测到两个实例同时运行。")"
  [[ -n "$BACKUP_APP" ]] && yellow "$(localize "Previous copy backup: $BACKUP_APP" "旧副本备份：$BACKUP_APP")"
  pause_before_close
  exit 2
fi

green "$(localize "Done: original WeChat and WeChat 2 are both running." "完成：原版微信和微信 2 已同时运行。")"
if [[ -n "$BACKUP_APP" ]]; then
  printf "$(localize 'Previous copy moved to Trash: %s\n' '旧副本已移到废纸篓：%s\n')" "$BACKUP_APP"
  printf '%s\n' "$(localize "Delete the backup manually after checking your second account and chat history." "确认第二个账号和聊天记录正常后，可以手动删除它。")"
fi

printf '%s\n' "$(localize "If macOS asks for notification, camera or microphone access, grant access as needed." "如果系统询问通知、相机或麦克风权限，请按需要重新授权。")"

printf '\n'
blue "$(localize "Change the WeChat 2 icon manually" "手动更换微信 2 图标")"
printf "$(localize 'Icon folder: %s\n' '图标文件夹：%s\n')" "$CUSTOM_ICON_DIR"
printf '%s\n' "$(localize "1. In Applications, right-click WeChat2.app and choose Get Info." "1. 在“应用程序”中右键点击 WeChat2.app 图标，选择“显示简介”。")"
printf '%s\n' "$(localize "2. Drag an icon from the wechat_icons folder onto the small icon at the top left of the Get Info window to replace it." "2. 将 wechat_icons 文件夹中的图标拖到“显示简介”窗口左上角的小图标上，覆盖原图标。")"
pause_before_close
