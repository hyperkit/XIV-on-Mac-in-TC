#!/bin/bash

# XIV on Mac in TC - 安裝／移除 DXMT nvngx.dll 修正版（DLSS → MetalFX）
# 用法: ./scripts/install-dxmt-nvngx.sh install <native/nvngx.dll 路徑>
#       ./scripts/install-dxmt-nvngx.sh uninstall
#       ./scripts/install-dxmt-nvngx.sh status
#
# 不修改已簽署的 App：把 build-dxmt-nvngx.sh 產生的 native/nvngx.dll 放進 wineprefix 的
# system32，並在 DllOverrides 設定 nvngx=native，讓 Wine 優先載入它而非 App 內的 v0.80 版本。
# 執行前請先完全關閉遊戲與啟動器。

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_PATH="${APP_PATH:-/Applications/XIV on Mac in TC.app}"
SUPPORT_DIR="${HOME}/Library/Application Support/XIV on Mac in TC"
PREFIX="${SUPPORT_DIR}/wineprefix"
SYSTEM32="${PREFIX}/drive_c/windows/system32"
TARGET="${SYSTEM32}/nvngx.dll"
BACKUP="${SYSTEM32}/nvngx.dll.dxmt-original"
WINE_BIN="${APP_PATH}/Contents/Resources/wine/bin"
OVERRIDE_KEY='HKCU\Software\Wine\DllOverrides'

wine_reg() {
    WINEPREFIX="$PREFIX" WINEDEBUG=-all "${WINE_BIN}/wine" reg "$@"
    WINEPREFIX="$PREFIX" "${WINE_BIN}/wineserver" -w
}

require_closed() {
    if pgrep -f 'ffxiv_dx11.exe' >/dev/null || pgrep -f "${APP_PATH}/Contents/MacOS/" >/dev/null; then
        echo -e "${RED}請先關閉遊戲與 XIV on Mac in TC 啟動器${NC}"
        exit 1
    fi
    [ -x "${WINE_BIN}/wine" ] || { echo -e "${RED}找不到 ${WINE_BIN}/wine，請以 APP_PATH 指定 App 位置${NC}"; exit 1; }
    [ -d "$SYSTEM32" ] || { echo -e "${RED}找不到 wineprefix：${PREFIX}${NC}"; exit 1; }
}

case "${1:-}" in
    install)
        SOURCE="${2:?請指定 native/nvngx.dll 路徑}"
        [ -f "$SOURCE" ] || { echo -e "${RED}找不到 ${SOURCE}${NC}"; exit 1; }
        if head -c 96 "$SOURCE" | tail -c 32 | grep -q 'Wine builtin DLL'; then
            echo -e "${RED}請使用 native/nvngx.dll（builtin 版本會被 Wine 改從 App 內載入）${NC}"
            exit 1
        fi
        require_closed
        if [ -f "$TARGET" ] && [ ! -f "$BACKUP" ]; then
            cp -p "$TARGET" "$BACKUP"
            echo -e "${YELLOW}已備份原始檔：${BACKUP}${NC}"
        fi
        cp "$SOURCE" "$TARGET"
        wine_reg add "$OVERRIDE_KEY" /v nvngx /d native /f >/dev/null
        echo -e "${GREEN}已安裝修正版 nvngx.dll 並設定 nvngx=native${NC}"
        ;;
    uninstall)
        require_closed
        wine_reg delete "$OVERRIDE_KEY" /v nvngx /f >/dev/null 2>&1 || true
        if [ -f "$BACKUP" ]; then
            mv -f "$BACKUP" "$TARGET"
            echo -e "${GREEN}已還原原始 nvngx.dll 並移除 nvngx 覆寫${NC}"
        else
            echo -e "${YELLOW}沒有備份檔；已移除 nvngx 覆寫，Wine 會改用 App 內的版本${NC}"
        fi
        ;;
    status)
        if head -c 96 "$TARGET" 2>/dev/null | tail -c 32 | grep -q 'Wine builtin DLL'; then
            echo "system32/nvngx.dll: App 內建版本（DXMT v0.80）"
        elif [ -f "$TARGET" ]; then
            echo "system32/nvngx.dll: 修正版（native）"
        else
            echo "system32/nvngx.dll: 不存在"
        fi
        if grep -q '^"nvngx"="native"' "${PREFIX}/user.reg" 2>/dev/null; then
            echo "DllOverrides: nvngx=native"
        else
            echo "DllOverrides: 未設定"
        fi
        ;;
    *)
        echo "用法: $0 install <native/nvngx.dll> | uninstall | status"
        exit 1
        ;;
esac
