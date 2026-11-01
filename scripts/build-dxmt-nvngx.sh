#!/bin/bash

# XIV on Mac in TC - DXMT nvngx.dll 修正版建置腳本
# 用法: ./scripts/build-dxmt-nvngx.sh [輸出目錄]
# 範例: ./scripts/build-dxmt-nvngx.sh Release/dxmt-nvngx
#
# 目前 runtime 內的 DXMT v0.80 nvngx.dll（DLSS → MetalFX 轉接）回傳錯誤的 NGX 錯誤碼，
# 遊戲會把失敗當成成功，進而使用未初始化的 handle 並在 nvngx.dll 內崩潰。
# 此腳本以 v0.80 為基礎，只套用上游 nvngx 的三個修正後重新編譯 nvngx.dll，
# 其餘 DXMT 元件維持 v0.80，介面不變。
#
# 需求: git、python3、x86_64-w64-mingw32-g++（macOS: brew install mingw-w64；
#       Ubuntu: apt install g++-mingw-w64-x86-64-posix）
#
# 輸出:
#   native/nvngx.dll   放到 wineprefix 的 system32 並設 DllOverrides nvngx=native（不需改動 App）
#   builtin/nvngx.dll  帶 Wine builtin 標記，用於替換 App 內 wine/lib/wine/x86_64-windows/

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-${PROJECT_DIR}/Release/dxmt-nvngx}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

DXMT_REPO="https://github.com/3Shain/dxmt.git"
DXMT_BASE="589adb780354b461645b29999cefaf533594ee99"  # v0.80
DXMT_FIXES=(
    "59eb4c1ad82df75fdf89fb05bc45acaed3767323"  # fix(nvngx): use correct nvngx error value (0xbad00000)
    "542ca170c7cfdd91630b513a28a96f95fa333258"  # fix(nvngx): use 1.0 as default pre-exposure value
    "50102f994b406f58f56d5d09f2ad20f9b90390a2"  # fix(nvngx): allow resources stored as `void *` to be read as D3D resources
)

CXX="${CXX:-x86_64-w64-mingw32-g++}"
CC="${CC:-x86_64-w64-mingw32-gcc}"
STRIP="${STRIP:-x86_64-w64-mingw32-strip}"

for tool in git python3 "$CXX" "$CC" "$STRIP"; do
    command -v "$tool" >/dev/null || { echo -e "${RED}找不到 ${tool}${NC}"; exit 1; }
done

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
SRC="$WORK_DIR/dxmt"

echo -e "${YELLOW}下載 DXMT v0.80 與 nvngx 修正...${NC}"
git init -q "$SRC"
git -C "$SRC" remote add origin "$DXMT_REPO"
git -C "$SRC" fetch -q --depth 1 origin "$DXMT_BASE"
git -C "$SRC" checkout -q FETCH_HEAD
for commit in "${DXMT_FIXES[@]}"; do
    git -C "$SRC" fetch -q --depth 2 origin "$commit"
    # 每個修正都只改 src/nvngx，直接套用其 diff
    git -C "$SRC" diff "${commit}^" "$commit" | git -C "$SRC" apply --index
done
git -C "$SRC" -c submodule.recurse=false submodule update -q --init --depth 1 include/native/directx

echo -e "${YELLOW}編譯 nvngx.dll...${NC}"
UTIL="$SRC/src/util"
CXXFLAGS=(
    -std=c++20 -O2 -DNDEBUG -DNOMINMAX -D_WIN32_WINNT=0xa00
    -Wno-unused-parameter -Wno-missing-field-initializers
    -I"$SRC/include" -I"$SRC/libs" -I"$UTIL"
    -I"$SRC/src/winemetal" -I"$SRC/src/dxgi" -I"$SRC/src/d3d11"
)
# 與 src/util/meson.build 的 Windows 交叉編譯清單一致
SOURCES=(
    "$SRC/src/nvngx/nvngx.cpp"
    "$UTIL/util_env.cpp" "$UTIL/util_string.cpp" "$UTIL/util_bloom.cpp" "$UTIL/thread.cpp"
    "$UTIL/com/com_guid.cpp" "$UTIL/com/com_private_data.cpp"
    "$UTIL/config/config.cpp" "$UTIL/log/log.cpp" "$UTIL/sha1/sha1_util.cpp"
    "$UTIL/wsi_monitor_win32.cpp" "$UTIL/wsi_window_win32.cpp" "$UTIL/wsi_platform_win32.cpp"
)
OBJ_DIR="$WORK_DIR/obj"
mkdir -p "$OBJ_DIR"
for source in "${SOURCES[@]}"; do
    "$CXX" "${CXXFLAGS[@]}" -c "$source" -o "$OBJ_DIR/$(basename "$source").o"
done
"$CC" -O2 -I"$UTIL" -c "$UTIL/sha1/sha1.c" -o "$OBJ_DIR/sha1.c.o"

mkdir -p "$OUTPUT_DIR/native" "$OUTPUT_DIR/builtin"
"$CXX" -shared -o "$OUTPUT_DIR/native/nvngx.dll" "$OBJ_DIR"/*.o \
    -static -Wl,--file-alignment=4096 -ldxgi -luuid -lole32
"$STRIP" "$OUTPUT_DIR/native/nvngx.dll"

# 與 winebuild --builtin 相同：在 DOS header 之後寫入 Wine builtin 簽章
python3 - "$OUTPUT_DIR/native/nvngx.dll" "$OUTPUT_DIR/builtin/nvngx.dll" <<'PY'
import struct, sys
data = bytearray(open(sys.argv[1], 'rb').read())
assert data[:2] == b'MZ' and struct.unpack_from('<I', data, 0x3c)[0] >= 0x60
data[0x40:0x60] = b'Wine builtin DLL'.ljust(32, b'\0')
open(sys.argv[2], 'wb').write(data)
PY

# 確認錯誤碼修正已編入（舊版為 0x0bad000x）
if "${CXX%g++}objdump" -d "$OUTPUT_DIR/native/nvngx.dll" 2>/dev/null | grep -qE '\$0xbad000[0-9a-f]\b'; then
    echo -e "${RED}nvngx.dll 仍含舊的錯誤碼${NC}"
    exit 1
fi

(
    cd "$OUTPUT_DIR"
    if command -v sha256sum >/dev/null; then
        sha256sum native/nvngx.dll builtin/nvngx.dll > SHA256SUMS
    else
        shasum -a 256 native/nvngx.dll builtin/nvngx.dll > SHA256SUMS
    fi
)
echo -e "${GREEN}完成：${OUTPUT_DIR}${NC}"
cat "$OUTPUT_DIR/SHA256SUMS"
