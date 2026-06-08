#!/bin/bash
set -e
# ============================================================
# fastcat macOS DMG 打包脚本
# 用法: ./scripts/package_dmg.sh
# 前置: flutter build macos --release --dart-define=XOR_KEY=...
# ============================================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 从 config.yaml 读取产品名
APP_NAME="快猫"
APP_NAME_EN="fastcat"
CONFIG_YAML="${PROJECT_DIR}/assets/config/config.yaml"
if [ -f "$CONFIG_YAML" ]; then
  YAML_APP_NAME=$(grep -E '^app_name:' "$CONFIG_YAML" | sed 's/^app_name:[[:space:]]*//' | tr -d '\r' | xargs)
  [ -n "$YAML_APP_NAME" ] && APP_NAME="$YAML_APP_NAME"
  YAML_APP_NAME_EN=$(grep -E '^app_name_en:' "$CONFIG_YAML" | sed 's/^app_name_en:[[:space:]]*//' | tr -d '\r' | xargs)
  [ -n "$YAML_APP_NAME_EN" ] && APP_NAME_EN="$YAML_APP_NAME_EN"
fi

# 从 pubspec.yaml 读取版本号（如 3.3.5+1 → 3.3.5）
VERSION=""
PUBSPEC="${PROJECT_DIR}/pubspec.yaml"
if [ -f "$PUBSPEC" ]; then
  RAW_VERSION=$(grep -E '^version:' "$PUBSPEC" | sed 's/^version:[[:space:]]*//' | tr -d '\r' | xargs)
  VERSION="${RAW_VERSION%%+*}"
fi

# DMG 文件名用英文名 + 版本号：fastcat-3.3.5.dmg
if [ -n "$VERSION" ]; then
  DMG_NAME="${APP_NAME_EN}-${VERSION}.dmg"
else
  DMG_NAME="${APP_NAME_EN}.dmg"
fi

APP="${PROJECT_DIR}/build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_PATH="${PROJECT_DIR}/dist/${DMG_NAME}"
# 卷标保持 ASCII（Finder 背景图 alias 要求）
VOL_NAME="fastcat"

BG_SRC="${PROJECT_DIR}/macos/packaging/dmg/background.png"
TMP_DMG="/tmp/fastcat-tmp.dmg"

[ -d "$APP" ] || { echo "❌ app 未构建: $APP"; exit 1; }

mount | grep -i fastcat | awk '{print $1}' | while read dev; do
  hdiutil detach "$dev" -force 2>/dev/null
done
rm -f "$TMP_DMG"

APP_SIZE=$(du -sk "$APP" | cut -f1)
DMG_SIZE=$((APP_SIZE * 3 / 1000 + 100))

echo "📦 创建 ${DMG_SIZE}MB HFS+ 镜像..."
hdiutil create -volname "$VOL_NAME" -size ${DMG_SIZE}m -fs "HFS+" -attach "$TMP_DMG"

cp -R "$APP" "/Volumes/${VOL_NAME}/"
ln -sf /Applications "/Volumes/${VOL_NAME}/Applications"
mkdir -p "/Volumes/${VOL_NAME}/.background"
cp "$BG_SRC" "/Volumes/${VOL_NAME}/.background/background.png"

echo "🎨 设置安装窗口..."
osascript -e "
tell application \"Finder\"
  tell disk \"${VOL_NAME}\"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {220, 120, 860, 572}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 144
    set background picture of viewOptions to file \".background:background.png\"
    set position of item \"${APP_NAME}.app\" of container window to {172, 236}
    set position of item \"Applications\" of container window to {476, 236}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
"

echo "💿 压缩转换..."
hdiutil detach "/Volumes/${VOL_NAME}"
rm -f "$DMG_PATH"
hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG_PATH"
rm -f "$TMP_DMG"

echo "✅ $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
