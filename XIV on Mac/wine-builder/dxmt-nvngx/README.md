# DXMT nvngx.dll 修正版

`package-runtime.sh` 準備好 winecx runtime 後，會以此目錄的 `nvngx.dll` 取代
runtime 內 `lib/wine/x86_64-windows/nvngx.dll`（DXMT v0.80 的 DLSS → MetalFX 轉接）。

此檔由 `scripts/build-dxmt-nvngx.sh` 產生（`builtin/nvngx.dll`），內容為 DXMT v0.80
加上上游 nvngx 修正 59eb4c1、542ca17、50102f9 與 `scripts/dxmt-nvngx-patches/`：

- 修正 NGX 錯誤碼，避免遊戲把失敗當成功後在 nvngx.dll 內崩潰
- 視窗縮放時遊戲傳入空的 DLSS handle 不再崩潰，並記錄失敗原因
- 支援 `DXMT_NVNGX_RENDER_SCALE`（設定 → 圖像 → 覆寫 DLSS 渲染比例）

nvngx.dll 只依賴 v0.80 未變動的 DXMT 介面，因此只在 runtime 的 winecx tag 與
`runtime-tag` 相同時才會替換。更新 winecx 後請確認其 DXMT 版本，再重新建置此檔並更新
`runtime-tag`；不相符時會沿用 runtime 原本的 nvngx.dll 並顯示警告。
