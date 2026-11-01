#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
python3 fetch-runtime.py

# 已移除的 D3DMetal 後端曾把 DXMT 的 DLL 移到 lib/dxmt，fetch-runtime.py 會沿用該 runtime，先還原
if [ -d ../wine/lib/dxmt/wine/x86_64-windows ]; then
    mv -f ../wine/lib/dxmt/wine/x86_64-windows/*.dll ../wine/lib/wine/x86_64-windows/
    rm -rf ../wine/lib/dxmt
fi
rm -rf ../wine/lib/gptk

# 以修正版 DXMT nvngx.dll 取代 runtime 內的版本，說明見 dxmt-nvngx/README.md
expected_tag="$(tr -d '[:space:]' < dxmt-nvngx/runtime-tag)"
runtime_tag="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["tag"])' ../wine/.winecx-runtime.json)"
if [ "$runtime_tag" = "$expected_tag" ]; then
    cp dxmt-nvngx/nvngx.dll ../wine/lib/wine/x86_64-windows/nvngx.dll
    echo "note: 已套用修正版 DXMT nvngx.dll"
else
    echo "warning: winecx ${runtime_tag} 與 nvngx.dll 對應的 ${expected_tag} 不同，沿用 runtime 原本的 nvngx.dll"
fi
