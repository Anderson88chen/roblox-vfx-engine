# CLAUDE.md — Claude / Claude Code 專案指令

本專案遵守跨模型共同規範 [AGENTS.md](AGENTS.md) 與單一事實來源 [docs/VFX_ENGINE_SPEC.md](docs/VFX_ENGINE_SPEC.md)。

## 核心守則（與 Gemini 完全同步）
1. **必讀規格**：產出任何特效前，必須先讀 `docs/VFX_ENGINE_SPEC.md`（錨點表、Schema、曲線簽名、免費貼圖 ID 清單）與 `src/ReplicatedStorage/VFXEngine/Core/Types.luau`。
2. **工作流檔案**：建立新 Aura 時依循 `.agent/workflows/create-aura.md` 的步驟與檢查清單。
3. **唯讀護欄**：**絕對不可修改** `src/ReplicatedStorage/VFXEngine/Core/`、`init.luau` 或 `VFXPreviewClient.client.luau`（除非使用者明確要求升級引擎核心）。
4. **Preset 標準**：
   - 存放於 `src/ReplicatedStorage/VFXEngine/Presets/<PascalCaseName>.luau`。
   - 首行強制 `--!strict`，引入 `Core.Types` 並回傳 `: Types.AuraPreset`。
   - 若有抽取區域曲線表或色點表，請顯式標註型別（如 `: Types.BezierCurveSpec`），或直接內聯於 `Preset` 主表內。
   - 嚴禁憑空編造 `rbxassetid://` 數字；僅限使用 `docs/VFX_ENGINE_SPEC.md` 第 6 節內建貼圖或 `tools/vfx_texture_gen.py` 產出並由使用者上傳後的 ID。
5. **即時預覽介面**：
   - `default.project.json` 對應 Rojo 7 標準結構。
   - 預覽切換由 `VFXPreviewClient.client.luau` 監聽 `ActiveAura`、`AuraScale`、`ReplayTrigger` 與 `ForceReload` 四個 Attribute 完成。
