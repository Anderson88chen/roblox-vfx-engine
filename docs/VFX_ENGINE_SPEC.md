# VFXEngine 單一事實來源規格書（Single Source of Truth, SSOT）

> **適用對象**：所有 AI 模型（Gemini、Claude）與人類開發者  
> **核心定位**：零成本、純 Luau 資料驅動之模組化 Roblox Aura & VFX 特效引擎，透過結構化設定檔（Preset）與離線程序化貼圖工具取代付費 Studio GUI 外掛。

---

## 1. 架構總覽與不可變原則

本引擎採 **Clean-Room 資料驅動架構**，將三類付費工具的能力抽象為標準化 Luau 模組與資料 Schema：

| 對標概念 | 引擎模組 | 核心職責 |
|---|---|---|
| **VFX Suite** | `Core/CurveUtils.luau` | 三次貝茲曲線（Cubic Bezier）與內建曲線轉換為合法 `NumberSequence`（`<= 20` Keypoints）；漸層色點自動排序轉換為 `ColorSequence`。 |
| **VFX Forge（骨架）** | `Core/RigBuilder.luau` | R15 / R6 自動偵測與地面高度校正，統一於 `HumanoidRootPart` 下建立標準 `Attachment` 與 3D 軌道錨點。 |
| **VFX Forge（工廠）** | `Core/InstanceFactory.luau` | 統一由設定資料生成 `ParticleEmitter`、`Beam`、`Trail`、`PointLight`，嚴格先設屬性再掛載 `Parent`。 |
| **VFX Forge（貼圖）** | `tools/vfx_texture_gen.py` | 離線使用 Pillow + NumPy 生成純白 RGB + 去背 Alpha 通道之徑向光暈、FBM 能量煙霧與幾何法陣 PNG。 |
| **Moon Animator** | `Core/OrbitController.luau` + `Core/TimelineRunner.luau` | 單一 `RunService.Heartbeat` 驅動 3D 傾角軌道與光源呼吸脈衝；輕量可取消多軌道時間軸（蓄力 → 爆發 → 常駐循環）。 |

### 不可變護欄
1. **Core 唯讀鎖定**：產出或修改特效時，**禁止修改** `src/ReplicatedStorage/VFXEngine/init.luau` 與 `Core/` 內任何檔案。
2. **嚴格型別強制**：所有 Preset 檔案（位於 `src/ReplicatedStorage/VFXEngine/Presets/`）第一行必須為 `--!strict`，並回傳明確標註為 `Types.AuraPreset` 的資料表。
3. **禁止 GUI 外掛**：本專案不建立任何給人類滑鼠點擊的 Studio Plugin UI。
4. **Roblox Attachment 鐵律**：`Attachment` 必須直接掛載於 `BasePart`（即 `HumanoidRootPart`）之下，**不可**放進 `Folder` 或巢狀掛在另一個 `Attachment` 底下，否則渲染引擎會忽略該錨點與相關 `ParticleEmitter` / `Beam` / `Trail`。

---

## 2. 標準 `Attachment` 錨點名稱表

`RigBuilder.Build(character, rigConfig, scale, sessionId)` 會自動偵測 `Humanoid.RigType`（`Enum.HumanoidRigType.R15` 或 `R6`）並依 `HipHeight`／腿部高度算出腳底基準面 `groundY`，在 `HumanoidRootPart` 下建立以下標準錨點（所有偏移量皆自動乘上 `scale`）：

| 錨點名稱（`anchor` / `anchor0` / `anchor1`） | 座標與用途說明 | 預設參數（於 `rig` 設定） |
|---|---|---|
| `RootCore` | `HumanoidRootPart` 中心 `(0, 0, 0)`，適合核心光球、發光點、全身聚能粒子。 | — |
| `Ground_Center` | 腳底地面中心 `(0, groundY + groundLift, 0)`，適合地面法陣、腳下煙霧與擴散衝擊波。 | `groundLift = 0.08` |
| `Overhead_Halo` | 角色頭頂上方 `(0, headTopY + haloOffset, 0)`，適合頭頂光環、王冠星塵。 | `haloOffset = 0.8` |
| `Pillar_Bottom` | 腳底基準點 `(0, groundY, 0)`，與 `Pillar_Top` 配對供垂直光柱 / 落雷 `Beam` 使用。 | — |
| `Pillar_Top` | 垂直光柱頂端 `(0, groundY + pillarHeight, 0)`，供天降雷柱或覺醒光柱 `Beam` 使用。 | `pillarHeight = 24` |
| `Orbit_1` .. `Orbit_N` | 動態 3D 傾角環繞節點，`N` 為 1 到 `orbitCount`（自動取 `rig.orbitCount` 與 `orbits` 最大 `anchorIndex` 之較大值）。 | 由 `orbits` 陣列驅動 |
| `Orbit_1_Top` .. `Orbit_N_Top` | 沿軌道平面法向量 `+trailHalfWidth` 偏移之附屬節點，供軌道 `Trail` 的 `anchor0` 使用。 | `trailHalfWidth = 0.35` |
| `Orbit_1_Bottom` .. `Orbit_N_Bottom` | 沿軌道平面法向量 `-trailHalfWidth` 偏移之附屬節點，供軌道 `Trail` 的 `anchor1` 使用。 | `trailHalfWidth = 0.35` |
| `<CustomKey>` | 由 `rig.customAnchors` 定義的自訂靜態錨點（鍵名不可與上述保留字衝突）。 | `customAnchors = { [string]: Vector3 }` |

---

## 3. Preset 資料結構 Schema（對應 `Core/Types.luau`）

所有 Preset 檔案必須遵守下列結構（請與 `Core/Types.luau` 保持欄位名稱與型別完全一致）：

```lua
--!strict
local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.AuraPreset = {
	meta = {
		id = "PresetName",
		displayName = "顯示名稱",
		author = "Gemini / Claude",
		description = "簡述視覺結構與階段節奏",
		tags = { "tag1", "tag2" },
	},
	rig = {
		orbitCount = 2,
		pillarHeight = 24,
		haloOffset = 0.8,
		groundLift = 0.08,
		customAnchors = nil, -- 選填：{ [string]: Vector3 }
	},
	orbits = { ... },     -- 選填：{ Types.OrbitSpec }
	particles = { ... },  -- 選填：{ Types.ParticleSpec }
	beams = { ... },      -- 選填：{ Types.BeamSpec }
	trails = { ... },     -- 選填：{ Types.TrailSpec }
	lights = { ... },     -- 選填：{ Types.LightSpec }
	timeline = { ... },   -- 選填：Types.TimelineConfig
}

return Preset
```

> **Luau `--!strict` 型別提示**：若在 Preset 中將曲線表抽成區域變數（例如 `local myCurve = { kind = "Bezier", ... }`），必須明確加上型別註記 `: Types.BezierCurveSpec`（或 `: Types.NumberCurveSpec`），否則建議直接內聯在 `Preset` 主表內讓 Luau 自動進行上下文型別推導。

### 3.1 `OrbitSpec`（3D 軌道定義）
| 欄位 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `id` | `string` | 必填 | 唯一軌道識別碼。 |
| `group` | `string?` | `"default"` | 軌道群組名，供時間軸 `SetOrbitSpeed` / `SetOrbitRadiusScale` 批次控制。 |
| `anchorIndex` | `number` | 必填 | 對應 `Orbit_<anchorIndex>` 與 `_Top` / `_Bottom`（`>= 1`）。 |
| `radius` | `number` | 必填 | 軌道半徑（studs，掛載時自動乘 `scale`）。 |
| `angularSpeed` | `number` | 必填 | 角速度（radians/sec；正值逆時針，負值順時針）。 |
| `phaseOffset` | `number?` | `0` | 初始相位角（radians，例如 `math.pi` 可對稱排列雙星）。 |
| `heightOffset` | `number?` | `0` | 在軌道平面法向上的基準高度偏移（studs）。 |
| `tiltDegrees` | `Vector3?` | `Vector3.zero` | 軌道平面 3D 歐拉傾角（度數 XYZ，例如 `Vector3.new(28, 0, 18)`）。 |
| `trailHalfWidth` | `number?` | `0.35` | `Orbit_N_Top` 與 `Orbit_N_Bottom` 各自距離中心的半寬。 |
| `radiusPulseAmp` | `number?` | `0` | 半徑呼吸振幅（studs）。 |
| `radiusPulseFreq` | `number?` | `0` | 半徑呼吸頻率（Hz）。 |
| `verticalBobAmp` | `number?` | `0` | 上下浮動振幅（studs）。 |
| `verticalBobFreq` | `number?` | `0` | 上下浮動頻率（Hz）。 |

### 3.2 `ParticleSpec`
| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | `string` | 必填，供 `TimelineStep.targetId` 指定。 |
| `tags` | `{ string }?` | 標籤清單，供 `TimelineStep.targetTag` 批次控制。 |
| `anchor` | `string` | 必填，第 2 節定義之錨點名稱。 |
| `enabledByDefault` | `boolean?` | 預設 `true`；爆發型粒子請設為 `false`。 |
| `texture` | `string` | 必填，僅可使用第 6 節核准貼圖或自產上傳之 `rbxassetid://`。 |
| `color` | `ColorCurveSpec?` | `Color3`、`ColorSequence` 或 `{ { time: number, color: Color3 } }`。 |
| `size` | `NumberCurveSpec?` | 隨生命週期變化的大小（會自動乘以掛載 `scale`）。 |
| `transparency` | `NumberCurveSpec?` | 自動夾限於 `[0, 1]`。 |
| `squash` | `NumberCurveSpec?` | 粒子縱橫擠壓曲線。 |
| `lifetime` | `NumberRangeSpec?` | `number`、`{ min, max }` 或 `NumberRange`。 |
| `rate` | `number?` | 每秒發射數量（單純爆發用粒子請設 `0`）。 |
| `speed` | `NumberRangeSpec?` | 初速度（會乘以 `scale`）。 |
| `spreadAngle` | `Vector2?` | 散射角（度數）。 |
| `acceleration` | `Vector3?` | 加速度（會乘以 `scale`）。 |
| `drag` | `number?` | 空氣阻力。 |
| `rotation` | `NumberRangeSpec?` | 初始旋轉角度（度數）。 |
| `rotSpeed` | `NumberRangeSpec?` | 旋轉速度（度數/秒）。 |
| `emissionDirection` | `Enum.NormalId?` | 發射方向。 |
| `orientation` | `Enum.ParticleOrientation?` | 粒子朝向模式（如 `VelocityParallel`、`FacingCamera`）。 |
| `lightEmission` | `number?` | 發光混合度 `[0, 1]`。 |
| `lightInfluence` | `number?` | 受環境光影響程度 `[0, 1]`。 |
| `brightness` | `number?` | 亮度倍率（預設 `1`，配合 Bloom 建議不超過 `4`）。 |
| `zOffset` | `number?` | 深度偏移。 |
| `lockedToPart` | `boolean?` | 是否跟隨錨點移動。 |
| `flipbookLayout` | `Enum.ParticleFlipbookLayout?` | 翻頁貼圖網格配置。 |
| `flipbookMode` | `Enum.ParticleFlipbookMode?` | 翻頁播放模式。 |
| `flipbookFramerate` | `NumberRangeSpec?` | 翻頁幀率。 |
| `timeScale` | `number?` | 時間縮放倍率。 |
| `velocityInheritance` | `number?` | 繼承角色速度比例。 |
| `windAffectsDrag` | `boolean?` | 是否受風場影響。 |

### 3.3 `BeamSpec`
| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | `string` | 必填。 |
| `tags` | `{ string }?` | 標籤陣列。 |
| `anchor0` | `string` | 必填，起點錨點名稱。 |
| `anchor1` | `string` | 必填，終點錨點名稱。 |
| `enabledByDefault` | `boolean?` | 預設 `true`。 |
| `texture` | `string?` | 貼圖 ID（預設 `""` 為純色光束）。 |
| `color` | `ColorCurveSpec?` | 沿光束色彩漸層。 |
| `transparency` | `NumberCurveSpec?` | 自動夾限 `[0, 1]`。 |
| `width0` / `width1` | `number?` | 兩端寬度（自動乘 `scale`）。 |
| `curveSize0` / `curveSize1` | `number?` | 貝茲彎曲控制強度（自動乘 `scale`）。 |
| `segments` | `number?` | 分段數（預設 `10`）。 |
| `textureLength` | `number?` | 貼圖重複長度。 |
| `textureMode` | `Enum.TextureMode?` | 貼圖平鋪模式。 |
| `textureSpeed` | `number?` | 貼圖流動速度。 |
| `faceCamera` | `boolean?` | 是否面向攝影機。 |
| `lightEmission` | `number?` | `[0, 1]`。 |
| `lightInfluence` | `number?` | `[0, 1]`。 |
| `brightness` | `number?` | 亮度倍率。 |
| `zOffset` | `number?` | 深度偏移。 |

### 3.4 `TrailSpec`
| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | `string` | 必填。 |
| `tags` | `{ string }?` | 標籤陣列。 |
| `anchor0` | `string` | 必填，建議填 `"Orbit_1_Top"`。 |
| `anchor1` | `string` | 必填，建議填 `"Orbit_1_Bottom"`。 |
| `enabledByDefault` | `boolean?` | 預設 `true`；啟用時引擎會先計算首幀位置並呼叫 `Trail:Clear()` 避免原點拉絲。 |
| `texture` | `string?` | 貼圖 ID（預設 `""` 為純色拖尾）。 |
| `color` | `ColorCurveSpec?` | 沿拖尾色彩漸層。 |
| `transparency` | `NumberCurveSpec?` | 自動夾限 `[0, 1]`。 |
| `widthScale` | `NumberCurveSpec?` | 拖尾寬度縮放曲線（自動夾限 `[0, 1]`）。 |
| `lifetime` | `number?` | 拖尾存在秒數。 |
| `minLength` | `number?` | 最小分段長度。 |
| `maxLength` | `number?` | 最大總長度（`0` 為不限）。 |
| `textureLength` | `number?` | 貼圖長度。 |
| `textureMode` | `Enum.TextureMode?` | 貼圖模式。 |
| `faceCamera` | `boolean?` | 設為 `true` 可確保從任何視角（含正俯視）都能看清拖尾寬度。 |
| `lightEmission` | `number?` | `[0, 1]`。 |
| `lightInfluence` | `number?` | `[0, 1]`。 |
| `brightness` | `number?` | 亮度倍率。 |

### 3.5 `LightSpec`
| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | `string` | 必填。 |
| `tags` | `{ string }?` | 標籤陣列。 |
| `anchor` | `string` | 必填，通常為 `"RootCore"` 或 `"Ground_Center"`。 |
| `enabledByDefault` | `boolean?` | 預設 `true`。 |
| `color` | `Color3?` | 光源顏色。 |
| `brightness` | `number?` | 基準亮度（建議 `0.5 ~ 3.5`）。 |
| `range` | `number?` | 照明半徑（引擎強制夾限 `[0, 60]`）。 |
| `shadows` | `boolean?` | 是否投射陰影（預設 `false` 以保效能）。 |
| `pulse` | `{ amplitude: number, frequency: number, rangeAmplitude: number?, phaseOffset: number? }?` | 呼吸脈衝正弦參數。 |

---

## 4. `CurveUtils` 函式簽名與內建曲線名稱

`Core/CurveUtils.luau` 提供下列公開函式（Engine 內部自動呼叫，不需在 Preset 裡手動呼叫，Preset 只需填寫對應 Spec）：

```lua
CurveUtils.CubicBezierToNumberSequence(spec: Types.BezierCurveSpec, clampMin: number?, clampMax: number?): NumberSequence
CurveUtils.ResolveNumberSequence(spec: Types.NumberCurveSpec?, defaultValue: number?, clampMin: number?, clampMax: number?, valueScale: number?): NumberSequence
CurveUtils.ResolveColorSequence(spec: Types.ColorCurveSpec?, defaultColor: Color3?): ColorSequence
CurveUtils.ResolveNumberRange(spec: Types.NumberRangeSpec?, defaultMin: number, defaultMax: number?, valueScale: number?): NumberRange
```

### 4.1 曲線規格支援格式（`NumberCurveSpec`）
1. **常數**：`number` → 自動轉為起點與終點相同值的 `NumberSequence`。
2. **原生序列**：`NumberSequence` → 自動裁切/保證在 `<= 20` Keypoints 內並夾限數值。
3. **三次貝茲曲線（`BezierCurveSpec`）**：
   `{ kind = "Bezier", y0 = 0, cx1 = 0.2, cy1 = 1.0, cx2 = 0.8, cy2 = 1.0, y3 = 0, samples = 12, envelope = 0, scale = 1 }`
   - 演算法：以 `P0 = (0, y0)`、`P1 = (clamp(cx1,0,1), cy1)`、`P2 = (clamp(cx2,0,1), cy2)`、`P3 = (1, y3)` 建立三次貝茲曲線，透過 16 次二分搜尋對齊目標時間 $u \in [0, 1]$，保證 `samples` 夾限於 `[2, 20]` 之間且時間單調遞增。
4. **內建預設曲線（`PresetCurveSpec`）**：
   `{ kind = "Preset", name = "FadeInOut", scale = 1, invert = false, samples = 12, envelope = 0 }`
   - 計算式：`baseValue = if invert then (1 - raw) else raw`，`finalValue = baseValue * (scale or 1)`。
   - 支援的 10 種內建 `PresetCurveName`：
     - `"Linear"`：線性 $0 \to 1$
     - `"EaseIn"`：緩入加速 $0 \to 1$
     - `"EaseOut"`：快入緩停 $0 \to 1$
     - `"EaseInOut"`：S 形平滑 $0 \to 1$
     - `"Bell"`：對稱鐘形 $0 \to 1 \to 0$（適合 Size 膨脹後收縮，或搭配 `invert = true` 作為 Transparency 淡入淡出）
     - `"FadeInOut"`：透明專用曲線，快速淡入 (`0.15` 秒點降至透明 `0`) 並於尾端淡出回 `1`（$1 \to 0 \to 0 \to 1$）
     - `"SharpDecay"`：瞬間峰值 $1$ 後快速指數衰減至 $0$（適合閃電與衝擊波）
     - `"Pulse"`：雙峰閃爍脈動 $0 \to 1 \to 0.35 \to 0.9 \to 0$
     - `"ShrinkOut"`：維持 $1$ 至中段後快速縮小歸 $0$
     - `"PopAndFade"`：彈出過衝至 $1.15$ 後平緩縮小至 $0$
5. **手動關鍵點（`KeypointsSpec`）**：
   `{ kind = "Keypoints", points = { { time = 0, value = 0 }, { time = 0.5, value = 1 }, { time = 1, value = 0 } } }`
   - 引擎會自動依 `time` 排序、補齊 `0` 與 `1` 端點，若超過 20 點會均勻重採樣至 20 點。

---

## 5. `TimelineStep` 時間軸動作規格

`timeline = { loop = boolean?, loopDuration = number?, steps = { TimelineStep } }`

每個 `TimelineStep` 於相對於播放起點 `time`（秒，`>= 0`）執行以下六種標準動作之一：

| `action` | 目標選擇欄位 | 動作參數欄位 | 行為說明 |
|---|---|---|---|
| `"SetEnabled"` | `targetId` 或 `targetTag` | `enabled: boolean` | 切換目標 `ParticleEmitter` / `Beam` / `Trail` / `PointLight` 之 `Enabled`。若目標為 `Trail` 且設為 `true`，引擎會自動呼叫 `Trail:Clear()`。 |
| `"EmitBurst"` | `targetId` 或 `targetTag` | `count: number` | 立即對目標 `ParticleEmitter` 呼叫 `emitter:Emit(count)` 觸發瞬間爆發。 |
| `"TweenBeamWidth"` | `targetId` 或 `targetTag` | `width0: number?`, `width1: number?`, `duration: number?`, `easingStyle: Enum.EasingStyle?`, `easingDirection: Enum.EasingDirection?` | 以 `TweenService` 平滑補間目標 `Beam` 的 `Width0` 與 `Width1`（數值自動乘以 `scale`）。 |
| `"FlashLight"` | `targetId` 或 `targetTag` | `peakBrightness: number?`, `peakRange: number?`, `duration: number?` | 使目標 `PointLight` 瞬間躍升至 `peakBrightness` 與 `peakRange`（上限 60），並在 `duration` 秒內以二次方緩出衰減回原脈衝狀態。 |
| `"SetOrbitSpeed"` | `targetId`（填軌道 `group` 名，若省略則套用 `"default"`） | `speedMultiplier: number` | 動態調整指定群組所有軌道的角速度倍率（例如蓄力加速 `2.2`、爆發後常駐 `1.2`）。 |
| `"SetOrbitRadiusScale"` | `targetId`（填軌道 `group` 名，若省略則套用 `"default"`） | `radiusMultiplier: number` | 動態調整指定群組所有軌道的半徑倍率（例如蓄力內縮 `0.65`、爆發外擴 `1.15`）。 |

---

## 6. 核准之 Roblox 內建免費貼圖清單

**嚴格禁止 AI 模型自行編造 `rbxassetid://` 數字**。撰寫 Preset 時僅允許使用以下經驗證的 Roblox 內建路徑，或使用由 `tools/vfx_texture_gen.py` 生成並經使用者實際上傳至 Roblox 後提供的 `rbxassetid://...`：

| 用途分類 | 貼圖路徑 | 視覺特徵與適用情境 |
|---|---|---|
| **純色實心帶** | `""`（空字串） | 無貼圖純色光帶；適合搭配動態寬度與透明度曲線的 `Trail` 與雷射 `Beam`。 |
| **星芒 / 閃光** | `rbxasset://textures/particles/sparkles_main.dds` | 十字星芒閃爍點；適合星界粒子、點綴微粒、光環閃點。 |
| **柔霧 / 煙雲** | `rbxasset://textures/particles/smoke_main.dds` | 柔和半透明雲霧；適合腳底氣霧、能量底層光暈與擴散煙塵。 |
| **火焰 / 電漿** | `rbxasset://textures/particles/fire_main.dds` | 流動感火焰與電漿絲帶；適合燃燒氣場、上升能量流。 |
| **火花 / 電流碎屑** | `rbxasset://textures/particles/fire_sparks_main.dds` | 高對比銳利火花；適合雷電火花、爆裂碎屑、蓄力電弧點。 |
| **核心光球 / 光暈** | `rbxasset://textures/particles/explosion01_core_main.dds` | 中心高亮徑向光團；適合核心能量球、頭頂光暈與爆發閃光核。 |
| **衝擊波環** | `rbxasset://textures/particles/explosion01_shockwave_main.dds` | 環狀擴散波紋；適合地板擴散法陣波紋與爆發瞬間衝擊環。 |
| **幾何方塊 / 結晶** | `rbxasset://textures/whiteSquare.png` | 純白清晰正方形；適合數位方塊、結晶碎片與幾何能量粒子。 |

### 自製離線貼圖流程（Pillow + NumPy）
若需要客製化對稱法陣、多八度 FBM 煙霧或銳利十字星芒，請執行：
```bash
python tools/vfx_texture_gen.py all
```
產出的純白 RGBA PNG 位於 `tools/output/`，可透過 Roblox Studio Asset Manager 或 Open Cloud 上傳為 Image Asset，取得真實 `rbxassetid://<ID>` 後再填入 Preset。由於貼圖 RGB 固定為純白 `(255, 255, 255)`，在 Roblox 中可直接透過 `ColorSequence` 染成任何顏色。

---

## 7. 效能與安全邊界（AI 自檢標準）

1. **Keypoint 上限**：每個 `NumberSequence` 與 `ColorSequence` 最多 **20** 個 Keypoints（`CurveUtils` 會自動夾限）。
2. **光源範圍上限**：所有 `PointLight.Range` 不得超過 `60`（`InstanceFactory` 與 `OrbitController` 會強制夾限至 `[0, 60]`），`Shadows` 預設 `false`。
3. **發射速率預算**：單一 Aura 全部持續型 `ParticleEmitter` 的 `Rate` 總和建議控制在 `<= 180 particles/sec`（爆發型改用 `Rate = 0` 搭配 `EmitBurst`）。
4. **Bloom 過曝控制**：`LightEmission` 與 `Brightness` 須適度配合（通常 `Brightness` 介於 `1.0 ~ 3.5`），避免全白刺眼過曝。
5. **公開引擎 API（`ReplicatedStorage.VFXEngine`）**：
   - `VFXEngine.GetPreset(presetName: string, forceReload: boolean?): Types.AuraPreset?`
   - `VFXEngine.ListPresets(): { string }`
   - `VFXEngine.Mount(character: Model, presetOrName: string | Types.AuraPreset, options: Types.MountOptions?): Types.AuraHandle?`
   - `VFXEngine.Unmount(character: Model)`
   - `VFXEngine.Reload(character: Model, presetOrName: string?, options: Types.MountOptions?): Types.AuraHandle?`
   - `VFXEngine.GetActive(character: Model): Types.AuraHandle?`
