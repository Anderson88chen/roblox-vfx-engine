# AGENTS.md — 跨 AI 模型通用開發規範（VFXEngine）

本專案採用「純 Luau 資料驅動框架 ＋ Python 離線程序化貼圖工具」架構，供 **Gemini**、**Claude** 與其他 AI 代理在同一套標準下無縫協作生成一致的 Roblox Aura / VFX 特效。

## 1. 單一事實來源（SSOT）
在進行任何特效設計、修改或審查前，**必須優先完整讀取**：
- `docs/VFX_ENGINE_SPEC.md`
- `src/ReplicatedStorage/VFXEngine/Core/Types.luau`（僅供唯讀查閱型別定義）

所有 `Attachment` 錨點名稱、Schema 欄位、曲線預設名、時間軸動作與內建免費貼圖清單皆以 `docs/VFX_ENGINE_SPEC.md` 為準，**禁止憑記憶猜測欄位或貼圖 ID**。

## 2. 嚴格修改邊界（唯讀鎖定）
- **禁止修改核心引擎**：除非使用者在對話中明確下令修改引擎底層，否則**絕對禁止修改**以下檔案：
  - `src/ReplicatedStorage/VFXEngine/init.luau`
  - `src/ReplicatedStorage/VFXEngine/Core/*`
  - `src/StarterPlayer/StarterPlayerScripts/VFXPreviewClient.client.luau`
- **禁止製作 Studio GUI 外掛**：本專案嚴禁撰寫任何給人類滑鼠點擊的 Studio Plugin / DockWidget / 屬性編輯視窗。所有特效一律以資料檔表達。
- **允許撰寫位置**：所有新增或調整的特效一律產出於：
  - `src/ReplicatedStorage/VFXEngine/Presets/<PascalCaseName>.luau`

## 3. Preset 撰寫強制標準
1. 檔案第一行必須是 `--!strict`。
2. 必須透過 `local Types = require(script.Parent.Parent.Core.Types)` 引入型別，並將回傳資料表標註為 `: Types.AuraPreset`。
3. 僅可使用 `docs/VFX_ENGINE_SPEC.md` 第 2 節定義之標準錨點（或該 Preset 自訂於 `rig.customAnchors` 的錨點）。
4. 僅可使用 `docs/VFX_ENGINE_SPEC.md` 第 6 節核准的 Roblox 內建 `rbxasset://` 貼圖路徑，或使用者透過 `tools/vfx_texture_gen.py` 產出並實際上傳後提供的 `rbxassetid://...`；**嚴禁編造任何未驗證的數字 Asset ID**。
5. 遵守效能與視覺邊界：
   - 單個 `PointLight.Range <= 60`，`Shadows = false`
   - 持續型粒子總發射率（`Rate` 加總）建議 `<= 180`
   - `NumberSequence` 與 `ColorSequence` Keypoints 上限為 20（由 `CurveUtils` 自動保證，仍建議合理指定 `samples`）
   - 若粒子或光源在特定階段才出現，請將 `enabledByDefault = false` 並於 `timeline.steps` 控制開關與爆發。

## 4. 離線貼圖生成規範
當內建貼圖無法滿足特殊幾何法陣、星芒或能量煙霧需求時，優先呼叫：
```bash
python tools/vfx_texture_gen.py --help
```
生成純白 RGB `(255, 255, 255)` + 去背 Alpha 通道之 PNG 至 `tools/output/`，提示使用者上傳至 Roblox 後再將取得的 `rbxassetid://` 填入 Preset。

## 5. 驗收與即時預覽規範
產出新 Preset 後，可透過以下方式在 Studio / Rojo 環境預覽（若已連線 Roblox Studio MCP 亦可直接驅動）：
- 修改 `Players.LocalPlayer`（或角色 Model）上的 Attribute：
  - `ActiveAura` (`string`): 設定為新 Preset 的模組名稱（如 `"AstralDualRing"`）
  - `AuraScale` (`number`): 縮放倍率（預設 `1`）
  - `ReplayTrigger` (`number`): 遞增數字以從 `t = 0` 重播時間軸
  - `ForceReload` (`boolean`): 設為 `true` 可在熱更新模組後強制繞過快取重新載入
- 測試快捷鍵（由 `VFXPreviewClient` 提供）：`K` 切換 Preset、`R` 重播當前特效時間軸。
