---
description: 建立符合 VFXEngine SSOT 規格的嚴格型別 (--!strict) Aura / VFX Preset
---

# `/create-aura` — 標準化 Aura & VFX 特效建立工作流

當使用者要求「製作某種風格的 Aura / 特效」時，所有 AI 模型（Gemini、Claude）必須依序執行以下步驟：

## Step 1: 讀取單一事實來源（SSOT）
1. 讀取 `docs/VFX_ENGINE_SPEC.md`，確認可用錨點（`RootCore`、`Ground_Center`、`Overhead_Halo`、`Pillar_Bottom`、`Pillar_Top`、`Orbit_N`、`Orbit_N_Top`、`Orbit_N_Bottom`、`customAnchors`）、曲線規範與核准貼圖清單。
2. 必要時檢視 `src/ReplicatedStorage/VFXEngine/Core/Types.luau` 確認欄位型別與選填預設值。
3. **切勿修改** `Core/`、`init.luau` 與 `VFXPreviewClient.client.luau`。

## Step 2: 規劃視覺分層與時間軸節奏
在撰寫程式碼前先規劃好以下四個維度：
- **色彩調性與發光控制**：決定主色、輔色、高光點，確保 `Brightness` 與 `LightEmission` 配合 Bloom 不會整片死白。
- **空間層次**：
  - 地面層（`Ground_Center`）：法陣波紋、底層能量霧、地面升騰微粒
  - 核心與頭頂層（`RootCore`、`Overhead_Halo`）：中心光球、核心點光源、頭頂光環
  - 3D 環繞層（`Orbit_1..N`）：設定傾斜角 `tiltDegrees`、角速度 `angularSpeed`、反相/交叉軌道與 `Trail` 拖尾
  - 天柱層（`Pillar_Bottom` -> `Pillar_Top`）：若為爆發型，規劃光柱 `Beam` 寬度動畫
- **時間軸編排（若為階段型）**：
  - 蓄力期（Charge）：內縮半徑、加速旋轉、聚能微粒
  - 爆發期（Burst）：瞬間 `EmitBurst`、`TweenBeamWidth` 閃現、`FlashLight`
  - 常駐期（Sustain）：展開軌道半徑、開啟主光環與拖尾

## Step 3:（選用）生成離線程序化貼圖
若需要特殊對稱法陣、多層煙霧或銳利星芒，執行 `tools/vfx_texture_gen.py` 生成純白去背 PNG：
```bash
python tools/vfx_texture_gen.py circle --sides 6 --rings 3 --inner-star --out tools/output/custom_circle.png
```
並告知使用者將產出圖檔上傳為 Roblox Asset 後取得 `rbxassetid://`（在尚未上傳前，先使用 `docs/VFX_ENGINE_SPEC.md` 第 6 節核准的內建免費 `rbxasset://` 貼圖確保立刻可預覽）。

## Step 4: 撰寫 `--!strict` Preset 檔案
於 `src/ReplicatedStorage/VFXEngine/Presets/<PascalCaseName>.luau` 建立檔案：
1. 第一行寫入 `--!strict`。
2. 引入型別：`local Types = require(script.Parent.Parent.Core.Types)`。
3. 將主表型別標註為 `local Preset: Types.AuraPreset = { ... }`。
4. 若 `timeline` 含有多階段開關，務必為爆發專用粒子／光束設定 `enabledByDefault = false`（且爆發粒子 `rate = 0`）。
5. 使用 `Bezier` 或 `Preset` 曲線描述尺寸與透明度變化，避免僵硬常數。

## Step 5: 靜態自檢與即時預覽
提交前逐項檢查：
- [ ] 首行包含 `--!strict`，且 `meta.id` 與檔名一致（PascalCase）。
- [ ] 未修改 `Core/`、`init.luau` 或 `VFXPreviewClient.client.luau`。
- [ ] 所有 `anchor` / `anchor0` / `anchor1` 名稱皆存在於標準錨點表或 `rig.customAnchors`。
- [ ] 所有 `texture` 僅使用 SSOT 核准內建路徑或有效 `rbxassetid://`。
- [ ] `PointLight.Range <= 60` 且 `shadows = false`。
- [ ] 提醒使用者可在 Studio 中透過 `ActiveAura = "<PresetName>"` 或按 `K` 鍵切換即時預覽。
