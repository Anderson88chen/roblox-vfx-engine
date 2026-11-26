# CinemaEngine 規格書（宣告式運鏡、過場與程序化動作引擎）

> **適用對象**：所有 AI 模型（Gemini、Claude）與人類開發者  
> **核心定位**：零成本、純 Luau `--!strict` 資料驅動之 Roblox 電影過場運鏡、字幕黑邊、跨引擎事件時間軸與 `Motor6D.Transform` 彈簧程序化骨架引擎，以宣告式資料表與執行期模組取代付費動畫／過場外掛。

---

## 1. 對標原版工具與最佳實踐對照表

| 對標概念與原版工具 | CinemaEngine 對應模組 | 實作機制與強化項目 |
|---|---|---|
| **Moon Animator 2**：Camera Track（`CFrame` / `FOV` / `Roll`） | `Core/SplineCameraRunner.luau` | 支援世界座標與角色局部偏移（`subjectOffset` / `lookAtOffset`）、**Catmull-Rom 樣條**與線性插值、荷蘭角（`rollDegrees`）與 `FieldOfView` 動態推進；播放前後完整快照並還原 `CameraType`、`CameraSubject`、`FieldOfView`。 |
| **Moon Animator 2**：多元 Easing 曲線 | `Core/SplineCameraRunner.luau` | 內建 `Linear`、`Sine`、`Quad`、`Cubic`、`Expo`、`Back` 搭配 `In` / `Out` / `InOut`，無需建立臨時 `Tween` 實例。 |
| **Moon Animator 2**：Subtitles & 過場黑邊 | `Core/LetterboxOverlay.luau` | 純程式碼於 `PlayerGui` 動態建置上下電影黑邊（`IgnoreGuiInset = true`）、片頭標題與時間軸淡入淡出字幕層；結束或中斷後徹底銷毀零殘留。 |
| **Moon Animator 2**：多軌道事件同步 | `Core/CutsceneSequencer.luau` | 統一以 `os.clock()` 時鐘驅動鏡頭、黑邊字幕與跨引擎事件軌（`VFXMount` / `VFXUnmount` / `VFXReplay`、`JuicePlay`、`AtmosApply` / `AtmosReset`、`RigImpulse`、`Callback`），透過 `FindFirstChild` + `pcall` 鬆耦合呼叫。 |
| **Procedural Spring Rig**：`Motor6D.Transform` 程序化動畫 | `Core/ProceduralRigController.luau` + `Core/SpringSolver.luau` | 相容 **R15**（`LowerTorso.Root`、`UpperTorso.Waist`、`Head.Neck`）與 **R6**（`HumanoidRootPart.RootJoint`、`Torso.Neck`）；綁定於 `RunService.Stepped`，採 `motor.Transform = motor.Transform * proceduralCFrame` 疊加呼吸、水平速度傾斜、起跳／落地衝擊與外部衝量，**絕不修改 `C0` / `C1`**。 |

---

## 2. 核心原理與關鍵避坑

### 2.1 為何必須在 `RunService.Stepped` 疊加 `Motor6D.Transform` 而非修改 `C0`/`C1`
1. **避免效能警告與重複計算**：頻繁每幀修改 `Motor6D.C0` / `C1` 會強制 Roblox 引擎立即重算關節空間並產生主控台效能警告；`Motor6D.Transform` 專為每幀動畫變換設計，由引擎批次處理。
2. **執行順序與動畫相容性**：Roblox 內建 `Animator` 會在 `Stepped` 之前寫入當幀骨骼動畫的 `Transform`。將 `ProceduralRigController` 綁定在 `RunService.Stepped`（注意簽章第二參數為 `dt`：`function(_stepTime, dt)`)，並以 **`motor.Transform = motor.Transform * proceduralCFrame`** 相乘疊加，即可將呼吸、奔跑傾斜與受擊彈簧無縫層疊於待機／奔跑／揮砍動畫之上，而不會覆蓋原生動作。
3. **無副作用卸載**：`DetachProceduralRig` 僅斷開 `Stepped` 與角色事件連線並停止寫入 `Transform`，不會留下任何永久性 `C0` / `C1` 偏移。

### 2.2 Catmull-Rom 樣條與與 `JuiceEngine` 相機震動疊加相容性
- **相鄰控制點端點補齊**：對於片段 $(k_i, k_{i+1})$，若為首段則以 $P_0 = P_1 + (P_1 - P_2)$ 生成虛擬前點，若為末段則以 $P_3 = P_2 + (P_2 - P_1)$ 生成虛擬後點，使路徑平滑通過所有關鍵幀控制點。
- **`RenderStep` 優先權協作**：`SplineCameraRunner` 綁定於 `Enum.RenderPriority.Camera.Value`，恰好位於 `JuiceEngine/Core/CameraShaker` 的前置還原（`Camera - 1`）與後置疊加（`Camera + 10`）之間，因此過場運鏡期間同時觸發 `JuicePlay` 相機震動與 `fovPunch` 時，震動會精準疊加於運鏡基準上且完全不累積漂移。

---

## 3. Preset 資料結構 Schema（對應 `Core/Types.luau`）

所有 Preset 檔案必須置於 `src/ReplicatedStorage/CinemaEngine/Presets/<PascalCaseName>.luau`，第一行必須為 `--!strict`，並回傳明確標註為 `Types.CutscenePreset` 的資料表：

```lua
--!strict
local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.CutscenePreset = {
	meta = {
		id = "PresetName",
		displayName = "顯示名稱",
		category = "Awakening",
		author = "CinemaEngine",
		description = "運鏡與三引擎連動說明",
		tags = { "tag1", "tag2" },
	},
	duration = 4.6,
	restoreAtmosOnEnd = true,
	restoreAtmosDuration = 0.75,
	unmountVFXOnEnd = true,
	camera = { ... },    -- 選填：Types.CameraTrackSpec
	letterbox = { ... }, -- 選填：Types.LetterboxTrackSpec
	subtitles = { ... }, -- 選填：{ Types.SubtitleCue }
	events = { ... },    -- 選填：{ Types.EngineEventStep }
}

return Preset
```

### 3.1 `CameraTrackSpec` 與 `CameraKeyframe`
- **`CameraTrackSpec`**：
  - `interpolation?: "CatmullRom" | "Linear"`（預設 `"CatmullRom"`）
  - `relativeToSubject?: boolean`（預設 `false`；若關鍵幀使用 `subjectOffset` / `lookAtOffset` 則自動視為相對座標）
  - `lockSubjectAtStart?: boolean`（預設 `false`；設為 `true` 可鎖定 `t = 0` 時的角色座標系）
  - `keyframes: { CameraKeyframe }`
- **`CameraKeyframe`**：
  - `time: number`（秒）
  - `position?: Vector3` / `lookAt?: Vector3`（世界座標或受 `relativeToSubject` 影響之局部座標）
  - `subjectOffset?: Vector3` / `lookAtOffset?: Vector3`（強制相對於 `subject` 根部 `CFrame` 之局部偏移）
  - `relativeToSubject?: boolean`
  - `fov?: number`（夾限 `15 ~ 115`，預設沿用原攝影機 FOV）
  - `rollDegrees?: number`（荷蘭角側傾度數，預設 `0`）
  - `easing?: "Linear" | "Sine" | "Quad" | "Cubic" | "Expo" | "Back"`（預設 `"Sine"`）
  - `direction?: "In" | "Out" | "InOut"`（預設 `"InOut"`）

### 3.2 `LetterboxTrackSpec` 與 `SubtitleCue`
- **`LetterboxTrackSpec`**：`enabled?`, `barRatio?`（預設 `0.115`）, `color?`, `fadeInDuration?`, `fadeOutDuration?`, `title?`, `subtitleHeading?`, `titleDuration?`
- **`SubtitleCue`**：`startTime`, `endTime?`, `duration?`, `speaker?`, `text`, `color?`, `fadeIn?`, `fadeOut?`

### 3.3 `EngineEventStep`（跨引擎時間軸動作）
| `action` | 常用欄位 | 說明 |
|---|---|---|
| `"VFXMount"` | `presetName`, `scale?`, `forceReload?` | 鬆耦合呼叫 `VFXEngine.Mount(subject, presetName, ...)`。 |
| `"VFXUnmount"` | — | 鬆耦合呼叫 `VFXEngine.Unmount(subject)`。 |
| `"VFXReplay"` | — | 重播目前角色身上已掛載之 `VFXEngine` 時間軸。 |
| `"JuicePlay"` | `presetName`, `intensity?`, `scale?`, `offset?`, `spatialOnly?` | 鬆耦合呼叫 `JuiceEngine.Play`；`spatialOnly = true` 時僅傳入空間座標／鏡頭震動與爆發，不觸發目標 `vfxTrigger` 重播。 |
| `"AtmosApply"` | `presetName`, `duration?`, `forceReload?` | 鬆耦合呼叫 `AtmosEngine.Apply`。 |
| `"AtmosReset"` | `duration?` | 鬆耦合呼叫 `AtmosEngine.Reset`。 |
| `"RigImpulse"` | `impulse: Vector3` | 對目標角色注入彈簧衝量 `(pitchRad, verticalStuds, rollRad)`。 |
| `"Callback"` | `callback: (EngineEventContext) -> ()` | 執行自訂 Luau 回呼（以 `pcall` 安全保護）。 |

---

## 4. 公開 API（`ReplicatedStorage.CinemaEngine`）

```lua
local CinemaEngine = require(game.ReplicatedStorage.CinemaEngine)
```

| 函式簽名 | 說明 |
|---|---|
| `CinemaEngine.GetPreset(presetName: string, forceReload: boolean?): Types.CutscenePreset?` | 讀取指定過場 Preset；`forceReload = true` 時繞過 `require` 快取熱重載。 |
| `CinemaEngine.ListPresets(): { string }` | 列出 `Presets/` 內所有可用 Preset 名稱（已排序）。 |
| `CinemaEngine.PlayCutscene(presetOrName: string \| Types.CutscenePreset, options: Types.CutscenePlayOptions?): Types.CinemaHandle?` | 播放過場動畫；自動中止前一段未結束過場，並在結束、中止、角色死亡或移除時還原攝影機與清除字幕黑邊。 |
| `CinemaEngine.StopCutscene()` | 立即中止當前過場並觸發完整攝影機與 UI 清理。 |
| `CinemaEngine.IsPlaying(): boolean` | 查詢目前是否正在播放過場。 |
| `CinemaEngine.AttachProceduralRig(character: Model, config: Types.ProceduralRigConfig?): boolean` | 為 R15 / R6 角色掛載呼吸、移動傾斜與跳躍落地彈簧程序化動作。 |
| `CinemaEngine.DetachProceduralRig(character: Model)` | 卸載指定角色之程序化骨架控制器。 |
| `CinemaEngine.ImpulseRig(character: Model, impulse: Vector3)` | 注入外部物理衝量至角色程序化彈簧（如揮砍後座力、受擊仰角）。 |

---

## 5. 安全邊界與規範

1. **攝影機狀態必定還原**：進入過場前必保存 `CameraType`、`CameraSubject`、`FieldOfView`、`CFrame`；無論正常播畢、`StopCutscene()`、角色死亡（`Humanoid.Died`）或離開 `DataModel`（`AncestryChanged`），必定還原原始 `CameraType`、`CameraSubject` 與 `FieldOfView`。
2. **禁止 Studio GUI 外掛**：`LetterboxOverlay.luau` 僅為執行期 `LocalPlayer.PlayerGui` 畫面元件；嚴禁建立任何 `DockWidgetPluginGui`、`CreateToolbar` 或 `PluginToolbar`。
3. **禁止編造數字 Asset ID**：嚴禁在任何 `.luau` 中編造未驗證的 `rbxassetid://<數字>`。
4. **唯讀紅線**：嚴禁修改 `VFXEngine` 核心與 `VFXPreviewClient.client.luau`；跨引擎呼叫一律以 `FindFirstChild` + `pcall` 鬆耦合完成。

---

## 6. 即時預覽控制（`CinemaPreviewClient.client.luau`）

在 Play 模式中可透過 `Players.LocalPlayer` 的 Attributes 或快捷鍵即時測試：

### LocalPlayer Attributes
| Attribute 名稱 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `ActiveCutscene` | `string` | `"AwakeningCutscene"` | 目前選用的過場 Preset 名稱。 |
| `CutsceneTrigger` | `number` | `0` | 每次遞增即播放當前選用的過場 Preset。 |
| `ProceduralRigEnabled` | `boolean` | `true` | 是否自動為當前與重生角色掛載呼吸／奔跑傾斜／落地彈簧手感。 |
| `CinemaForceReload` | `boolean` | `false` | 設為 `true` 可於播放時強制熱重載 Preset 模組。 |

### 預覽快捷鍵
- **`C`**：播放／中止當前選用之過場運鏡 Preset。
- **`V`**：依序循環切換下一個過場運鏡 Preset（更新 `ActiveCutscene`）。
