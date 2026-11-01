#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
python3 fetch-runtime.py

runtime_lib="../wine/lib"
runtime_windows="$runtime_lib/wine/x86_64-windows"
# 由 DXMT 或 D3DMetal 提供、需依圖形後端切換的 DLL
backend_dlls=(d3d10.dll d3d10core.dll d3d11.dll d3d12.dll d3d12core.dll dxgi.dll nvapi64.dll nvngx.dll)

# fetch-runtime.py 會沿用既有 runtime，先還原上次建置拆出的 DXMT 後端
if [ -d "$runtime_lib/dxmt" ]; then
    for dll in "${backend_dlls[@]}"; do
        if [ -f "$runtime_lib/dxmt/wine/x86_64-windows/$dll" ]; then
            mv -f "$runtime_lib/dxmt/wine/x86_64-windows/$dll" "$runtime_windows/$dll"
        fi
    done
    rm -rf "$runtime_lib/dxmt"
fi
rm -rf "$runtime_lib/gptk"

# 以修正版 DXMT nvngx.dll 取代 runtime 內的版本，說明見 dxmt-nvngx/README.md
expected_tag="$(tr -d '[:space:]' < dxmt-nvngx/runtime-tag)"
runtime_tag="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["tag"])' ../wine/.winecx-runtime.json)"
if [ "$runtime_tag" = "$expected_tag" ]; then
    cp dxmt-nvngx/nvngx.dll "$runtime_windows/nvngx.dll"
    echo "note: 已套用修正版 DXMT nvngx.dll"
else
    echo "warning: winecx ${runtime_tag} 與 nvngx.dll 對應的 ${expected_tag} 不同，沿用 runtime 原本的 nvngx.dll"
fi

# 選用的 D3DMetal 後端，說明見 GPTK.md。Wine 一定先搜尋 lib/wine，
# 因此兩個後端的 DLL 都要移出 lib/wine，再由 App 以 WINEDLLPATH 選擇其一。
if [ -d gptk/external ] && [ -f gptk/wine/x86_64-windows/d3d11.dll ]; then
    mkdir -p "$runtime_lib/dxmt/wine/x86_64-windows"
    for dll in "${backend_dlls[@]}"; do
        if [ -f "$runtime_windows/$dll" ]; then
            mv "$runtime_windows/$dll" "$runtime_lib/dxmt/wine/x86_64-windows/$dll"
        fi
    done
    # 保留 GPTK 的目錄結構與符號連結（x86_64-unix/*.so 指向 ../../external）
    if command -v ditto >/dev/null; then
        ditto gptk "$runtime_lib/gptk"
    else
        cp -a gptk "$runtime_lib/gptk"
    fi
    for arch_dir in x86_64-windows x86_64-unix; do
        for source in "$runtime_lib/gptk/wine/$arch_dir"/nvngx-on-metalfx.*; do
            [ -e "$source" ] || [ -L "$source" ] || continue
            mv -f "$source" "$runtime_lib/gptk/wine/$arch_dir/nvngx.${source##*.}"
        done
    done
    echo "note: 已加入 D3DMetal 後端（$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' gptk/external/D3DMetal.framework/Resources/Info.plist 2>/dev/null || echo 版本不明)）"
fi
