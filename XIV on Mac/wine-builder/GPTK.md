# 選用：D3DMetal（Apple Game Porting Toolkit）圖形後端

預設以 DXMT 將 Direct3D 11 轉為 Metal。若在本機放入 Apple 的
「Evaluation environment for Windows games」（GPTK），建置時會另外加入 D3DMetal 後端，
可在「設定 → 圖像 → 圖形後端」切換，於下次啟動遊戲時生效。

GPTK 依 Apple 授權不可提交到本 repository；`wine-builder/gptk/` 已列入 `.gitignore`。

## 設定

1. 從 Apple Developer 下載並掛載 Evaluation environment for Windows games（4.0 beta 3 以上）。
2. 將其中的 `redist/lib` 複製為 `XIV on Mac/wine-builder/gptk`，保留符號連結：

   ```bash
   ditto "/Volumes/Evaluation environment for Windows games 4.0 beta 3/redist/lib" "XIV on Mac/wine-builder/gptk"
   ```

   完成後應有 `gptk/external/D3DMetal.framework` 與 `gptk/wine/x86_64-windows/d3d11.dll`。
3. 重新建置。建置記錄出現 `note: 已加入 D3DMetal 後端` 即表示已打包。

## 運作方式

Wine 一定先從 runtime 的 `lib/wine` 載入內建 DLL，之後才搜尋 `WINEDLLPATH`。因此
`package-runtime.sh` 會把兩個後端都會提供的 DLL（`d3d10`、`d3d10core`、`d3d11`、`d3d12`、
`d3d12core`、`dxgi`、`nvapi64`、`nvngx`）移到 `lib/dxmt/wine`，GPTK 複製到 `lib/gptk`
（`nvngx-on-metalfx` 改名為 `nvngx` 以啟用 DLSS → MetalFX），App 再依設定把其中一個加入
`WINEDLLPATH`。沒有 `gptk/` 時 runtime 與原本相同。

D3DMetal 模式下 DXMT 專屬設定（MetalFX 空間縮放、DLSS 渲染比例覆寫）不會生效；
App 會設定 `D3DM_ENABLE_METALFX=1`。
