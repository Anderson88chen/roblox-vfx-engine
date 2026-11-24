# Roblox VFXEngine

零成本、純 Luau、資料驅動的 Roblox Aura / VFX 特效框架，外加一支 Python 離線去背貼圖生成器。
用結構化的 Preset 設定檔描述特效（粒子、光束、軌道、時間軸），不需要任何付費 Studio 外掛。

## 目錄結構

```
.
├── default.project.json            # Rojo 7 專案設定
├── src/
│   ├── ReplicatedStorage/VFXEngine/
│   │   ├── init.luau               # 引擎入口
│   │   ├── Core/                   # 核心模組（曲線、骨架錨點、實例工廠、軌道、時間軸、型別）
│   │   └── Presets/                # 特效 Preset（每個 Aura 一個檔案）
│   └── StarterPlayer/StarterPlayerScripts/
│       └── VFXPreviewClient.client.luau   # Play 模式即時預覽
├── tools/
│   ├── vfx_texture_gen.py          # 離線貼圖生成器
│   └── output/                     # 範例貼圖輸出
├── docs/VFX_ENGINE_SPEC.md         # 規格書（錨點表、Schema、曲線、內建貼圖 ID）
├── .agent/workflows/create-aura.md # 新增 Aura 的工作流程
├── AGENTS.md / CLAUDE.md / GEMINI.md  # AI 協作規範
```

## 快速上手

1. 安裝 [Rojo 7](https://rojo.space/)（CLI + Studio 外掛）。
2. 在專案根目錄啟動同步：
   ```bash
   rojo serve default.project.json
   ```
3. 開啟 Roblox Studio，在 Rojo 外掛按 **Connect**。
4. 按 **Play** 進入遊戲測試：
   - `K`：切換下一個 Aura Preset
   - `R`：重播目前特效

預覽腳本也會監聽 `ActiveAura`、`AuraScale`、`ReplayTrigger`、`ForceReload` 四個 Attribute，可以從指令列或其他腳本切換特效。

## Python 貼圖工具

```bash
pip install pillow numpy
python tools/vfx_texture_gen.py all
```

會在 `tools/output/` 產生純白 RGB + 平滑 Alpha 的 PNG（徑向光暈、星芒、FBM 煙霧、魔法陣），上傳到 Roblox 後用 `ColorSequence` 染色即可。
個別參數請見 `python tools/vfx_texture_gen.py --help`。

## 用 Gemini / Claude 生成新 Preset

1. 讓 AI 先讀 [`AGENTS.md`](AGENTS.md) 與 [`docs/VFX_ENGINE_SPEC.md`](docs/VFX_ENGINE_SPEC.md)（以及 `Core/Types.luau`）。
2. 依 [`.agent/workflows/create-aura.md`](.agent/workflows/create-aura.md) 的步驟描述想要的特效，例如：
   > 依照 VFX_ENGINE_SPEC 幫我做一個「冰霜護盾」Aura，地面法陣 + 三條傾斜軌道 + 頭頂光環。
3. 產出的檔案放在 `src/ReplicatedStorage/VFXEngine/Presets/<PascalCaseName>.luau`，首行 `--!strict`，回傳 `Types.AuraPreset`。
4. 貼圖只能用規格書第 6 節的內建 ID，或用 `tools/vfx_texture_gen.py` 產出後自行上傳取得的 ID。

內建範例：`AstralDualRing`、`ThunderAwakening`。

> `Core/`、`init.luau`、`VFXPreviewClient.client.luau` 為引擎核心，新增特效時不需要修改。
