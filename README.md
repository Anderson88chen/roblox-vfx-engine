# Roblox AI 宣告式核心工具鏈（VFXEngine Suite）

零成本、純 Luau（`--!strict`）、資料驅動的 Roblox 遊戲核心引擎套件，延續「厚核心、薄預覽」與單一事實來源（SSOT）工程原則，透過結構化 Preset 設定檔與執行期引擎取代付費 Studio GUI 外掛。

## 引擎套件總覽

| 引擎 | 對標原版工具 | 核心職責 | 規格書 |
|---|---|---|---|
| **VFXEngine** | VFX Forge / VFX Suite / Moon Animator（特效軌） | 3D 傾角軌道、貝茲曲線序列化、粒子／光束／拖尾／光源時間軸與 Python 離線貼圖生成 | [`docs/VFX_ENGINE_SPEC.md`](docs/VFX_ENGINE_SPEC.md) |
| **AtmosEngine** | Atmos / Lighting Settings Saver | 光影與大氣預設庫、非破壞性原始快照備份與還原、世代安全平滑補間、區域包圍盒與日夜循環 | [`docs/ATMOS_ENGINE_SPEC.md`](docs/ATMOS_ENGINE_SPEC.md) |
| **JuiceEngine** | EZ Camera Shake / Game Feel Director | 零漂移雙段 `RenderStep` 相機震動、世代安全頓幀、Highlight 閃光池、2D/3D 隨機音高音效池與世界爆發粒子 | [`docs/JUICE_ENGINE_SPEC.md`](docs/JUICE_ENGINE_SPEC.md) |
| **CinemaEngine** | Moon Animator 2（運鏡與過場）／ Procedural Rig | Catmull-Rom 樣條運鏡、電影黑邊與字幕、跨引擎時間軸同步與 `Motor6D.Transform` 彈簧程序化骨架 | [`docs/CINEMA_ENGINE_SPEC.md`](docs/CINEMA_ENGINE_SPEC.md) |
| **WorldGenEngine** | Archimedes / Brushtool 2.1 / RopeMaster | 共邊樞紐弧線／圓環建築、種子化 2D 泊松盤地表散布與坡度過濾、Catenary 懸鏈線繩索與垂掛燈飾 | [`docs/WORLDGEN_ENGINE_SPEC.md`](docs/WORLDGEN_ENGINE_SPEC.md) |

## 目錄結構

```text
.
├── default.project.json                        # Rojo 7 專案設定（同步五大引擎與預覽客戶端）
├── src/
│   ├── ReplicatedStorage/
│   │   ├── VFXEngine/                          # 特效引擎（Core 唯讀鎖定）
│   │   ├── AtmosEngine/                        # 光影與氛圍管理引擎
│   │   ├── JuiceEngine/                        # 打擊感與多感官中控引擎
│   │   ├── CinemaEngine/                       # 宣告式運鏡、過場與程序化動作引擎
│   │   └── WorldGenEngine/                     # 參數化幾何拼接、表面散布與懸索生成引擎
│   └── StarterPlayer/StarterPlayerScripts/
│       ├── VFXPreviewClient.client.luau        # VFXEngine Play 模式預覽
│       ├── AtmosPreviewClient.client.luau      # AtmosEngine Play 模式預覽
│       ├── JuicePreviewClient.client.luau      # JuiceEngine Play 模式預覽
│       ├── CinemaPreviewClient.client.luau     # CinemaEngine Play 模式預覽
│       └── WorldGenPreviewClient.client.luau   # WorldGenEngine Play 模式預覽
├── tools/
│   ├── vfx_texture_gen.py                      # 離線貼圖生成器（Pillow + NumPy）
│   ├── verify_engines.py                       # 跨引擎靜態合規與唯讀紅線檢查工具
│   └── output/                                 # 範例貼圖輸出
├── docs/
│   ├── VFX_ENGINE_SPEC.md
│   ├── ATMOS_ENGINE_SPEC.md
│   ├── JUICE_ENGINE_SPEC.md
│   ├── CINEMA_ENGINE_SPEC.md
│   └── WORLDGEN_ENGINE_SPEC.md
├── .agent/workflows/create-aura.md             # 新增 Aura 的工作流程
└── AGENTS.md / CLAUDE.md / GEMINI.md           # AI 跨模型協作規範
```

## 快速上手（Rojo 7 + Play 即時預覽）

1. 安裝 [Rojo 7](https://rojo.space/)（CLI + Studio 外掛）。
2. 在專案根目錄啟動同步：
   ```bash
   rojo serve default.project.json
   ```
3. 開啟 Roblox Studio，在 Rojo 外掛按 **Connect**，並按下 **Play** 進入測試模式。

### Play 模式快捷鍵總覽

| 快捷鍵 | 所屬引擎 | 動作說明 |
|---|---|---|
| `K` | `VFXEngine` | 循環切換下一個 Aura Preset |
| `R` | `VFXEngine` | 重播目前 Aura 時間軸 |
| `L` | `AtmosEngine` | 循環切換光影氛圍 Preset（含 `"None"` 還原原始光影） |
| `N` | `AtmosEngine` | 開關日夜循環（預設 `0.25` 小時/秒） |
| `J` | `JuiceEngine` | 立即觸發當前打擊感 Preset |
| `H` | `JuiceEngine` | 循環切換下一個 Juice Preset |
| `C` | `CinemaEngine` | 播放／中止當前過場運鏡 Preset |
| `V` | `CinemaEngine` | 循環切換下一個過場運鏡 Preset |
| `G` | `WorldGenEngine` | 循環生成／切換場景 Preset（最後切回 `"None"` 清除） |

### `Players.LocalPlayer` Attributes 控制表

| 引擎 | Attribute 名稱 | 型別 | 預設值 | 用途 |
|---|---|---|---|---|
| `VFXEngine` | `ActiveAura` / `AuraScale` / `ReplayTrigger` / `ForceReload` | `string` / `number` / `number` / `boolean` | `"AstralDualRing"` / `1` / `0` / `false` | 控制角色身上掛載的 Aura、縮放與熱重載 |
| `AtmosEngine` | `ActiveAtmos` / `AtmosTransitionDuration` / `AtmosDayNightSpeed` / `AtmosForceReload` | `string` / `number` / `number` / `boolean` | `"None"` / `1.2` / `0` / `false` | 切換或還原光影、控制補間秒數與日夜流速 |
| `JuiceEngine` | `ActiveJuice` / `JuiceIntensity` / `JuiceTrigger` / `JuiceForceReload` | `string` / `number` / `number` / `boolean` | `"HeavySlashHit"` / `1` / `0` / `false` | 觸發與調校打擊震動、頓幀、閃白與爆發特效 |
| `CinemaEngine` | `ActiveCutscene` / `CutsceneTrigger` / `ProceduralRigEnabled` / `CinemaForceReload` | `string` / `number` / `boolean` / `boolean` | `"AwakeningCutscene"` / `0` / `true` / `false` | 觸發過場運鏡與開關程序化彈簧骨架手感 |
| `WorldGenEngine` | `ActiveWorldScene` / `WorldSeed` / `WorldOriginOffset` / `WorldGenForceReload` | `string` / `number` / `Vector3` / `boolean` | `"None"` / `42` / `Vector3.zero` / `false` | 即時生成或清除程序化建築、散布與懸索場景 |

## Python 工具

### 1. 離線去背貼圖生成
```bash
pip install pillow numpy
python tools/vfx_texture_gen.py all
```
會在 `tools/output/` 產生純白 RGB + 平滑 Alpha 的 PNG（徑向光暈、星芒、FBM 煙霧、魔法陣），上傳到 Roblox 後即可搭配 `ColorSequence` 染色使用。

### 2. 靜態合規與專案結構檢查
```bash
python tools/verify_engines.py
```
自動檢查 `VFXEngine` 核心唯讀鎖定、零 Studio GUI API、`--!strict` 標頭、禁止編造數字 `rbxassetid://`、括號平衡、相對 `require(...)` 路徑與 `default.project.json` 同步結構。

## AI 協作與唯讀護欄

- 新增或修改 `VFXEngine` 特效時，請先讀 [`AGENTS.md`](AGENTS.md) 與 [`docs/VFX_ENGINE_SPEC.md`](docs/VFX_ENGINE_SPEC.md)，依 [`.agent/workflows/create-aura.md`](.agent/workflows/create-aura.md) 產出於 `src/ReplicatedStorage/VFXEngine/Presets/`。
- `src/ReplicatedStorage/VFXEngine/init.luau`、`src/ReplicatedStorage/VFXEngine/Core/*` 與 `src/StarterPlayer/StarterPlayerScripts/VFXPreviewClient.client.luau` 為唯讀鎖定核心，請勿更動。
- 嚴禁編造未驗證的數字 `rbxassetid://`，亦禁止撰寫任何 Studio Plugin GUI 外掛視窗。
