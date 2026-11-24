# GEMINI.md — Gemini / Antigravity 專案指令

本專案遵守跨模型共同規範 [AGENTS.md](AGENTS.md) 與單一事實來源 [docs/VFX_ENGINE_SPEC.md](docs/VFX_ENGINE_SPEC.md)。

## 工作流程與指令觸發
當使用者提出「製作／新增／設計某種風格的 Aura 或 VFX 特效」時，請遵循 [.agent/workflows/create-aura.md](.agent/workflows/create-aura.md) 的標準步驟執行：
1. 先讀取 `docs/VFX_ENGINE_SPEC.md` 與 `src/ReplicatedStorage/VFXEngine/Core/Types.luau`。
2. 參考現有範例（`Presets/AstralDualRing.luau` 與 `Presets/ThunderAwakening.luau`）的層次結構與時間軸寫法。
3. 僅在 `src/ReplicatedStorage/VFXEngine/Presets/` 下建立或編輯 `--!strict` `.luau` Preset，嚴禁更動 `Core/` 與 `init.luau`。
4. 若需要自製法陣或能量貼圖，使用 `tools/vfx_texture_gen.py` 產出圖檔至 `tools/output/`。

## 與 Roblox Studio MCP / Rojo 協作提示
- 本專案已配置 `default.project.json` 供 Rojo 7 同步，亦可使用 Roblox Studio MCP 的 `execute_luau` / `start_stop_play` 進行實機預覽。
- 在 Play 模式中，透過設定 `LocalPlayer:SetAttribute("ActiveAura", "<PresetName>")` 與遞增 `ReplayTrigger` 即可觸發 `VFXPreviewClient` 無縫銷毀舊特效並掛載新特效。
- 若編輯了既有 Preset 且處於熱重載預覽狀態，將 `LocalPlayer:SetAttribute("ForceReload", true)` 並重新觸發 `ActiveAura` / `ReplayTrigger` 即可立即生效。
