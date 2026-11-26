# JuiceEngine 規格書（打擊感與多感官中控引擎）

> **適用對象**：所有 AI 模型（Gemini、Claude）與人類開發者  
> **核心定位**：零成本、純 Luau 資料驅動之 Roblox 打擊感（Game Feel）中控引擎，整合零漂移相機震動、安全世代頓幀、受擊閃光物件池、空間音效池與世界座標粒子爆發，取代分散的付費外掛與臨時腳本。

---

## 1. 對標原版工具功能對照表

| 對標概念與原版工具 | JuiceEngine 對應模組 | 實作機制與強化項目 |
|---|---|---|
| **EZ Camera Shake / CameraShaker** | `Core/CameraShaker.luau` | 支援多實例疊加之阻尼簡諧／Perlin 噪聲（`math.noise`）震動、`fovPunch` 與 3D 空間距離衰減；採雙段 `BindToRenderStep`（`Camera - 1` 精確還原、`Camera + 10` 疊加偏移），在 Roblox `Custom` 攝影機模式下**保證零視角漂移**。 |
| **Game Feel Director（Hitstop）** | `Core/HitstopController.luau` | 支援同時對攻擊者與受擊者 `Model` 陣列調整 `Animator` 軌道速度與 `ParticleEmitter.TimeScale`；採**目標專屬世代編號（Per-Target Generation）**並保留真正頓幀前原始速度，重疊觸發或角色死亡／移除時**絕不卡死在 0 速**。 |
| **Hit-Flash Highlight 工具** | `Core/HitFlashRunner.luau` | 嚴格上限 **16** 個 `Highlight` 之循環複用池（遠低於 Roblox 全域 31 個 `Highlight` 上限），支援瞬間閃色並平順漸變淡出，目標移除時自動回收不損毀池實例。 |
| **Sound Pool（空間音效管理）** | `Core/SoundPool.luau` | 分離 2D（`SoundService` 資料夾）與 3D（`Workspace.Terrain` 池化 `Attachment`）音效池；支援隨機音高（`pitchRange`）、音量範圍（`volumeRange`）、衰減距離與同組最大併發限制，所有設定與 `Play()` 均以 `pcall` 包裹。 |
| **VFX Suite（爆發預覽）／VFXEngine 連動** | `Core/WorldBurstEmitter.luau` | 於世界座標 `Vector3` / `CFrame` 透過 `Workspace.Terrain` 池化 `Attachment` 瞬間 `:Emit()` 火花、衝擊波環與 `PointLight` 閃光；並以 `FindFirstChild("VFXEngine")` 鬆耦合安全連動 `VFXEngine.Mount` 與 `timeline:Replay()`。 |

---

## 2. Preset 資料結構 Schema（對應 `Core/Types.luau`）

所有 Preset 檔案必須置於 `src/ReplicatedStorage/JuiceEngine/Presets/<PascalCaseName>.luau`，第一行必須為 `--!strict`，並回傳明確標註為 `Types.JuicePreset` 的資料表：

```lua
--!strict
local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.JuicePreset = {
	meta = {
		id = "PresetName",
		displayName = "顯示名稱",
		category = "Melee",
		author = "JuiceEngine",
		description = "打擊感結構說明",
		tags = { "tag1", "tag2" },
	},
	cameraShake = { ... }, -- 選填：Types.CameraShakeSpec
	hitstop = { ... },     -- 選填：Types.HitstopSpec
	hitFlash = { ... },    -- 選填：Types.HitFlashSpec
	sounds = { ... },      -- 選填：{ Types.SoundSpec }
	worldBurst = { ... },  -- 選填：Types.WorldBurstSpec
	vfxTrigger = { ... },  -- 選填：Types.VFXTriggerSpec
}

return Preset
```

### 2.1 `CameraShakeSpec`
| 欄位 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `magnitude` | `number` | 必填 | 震動強度基準倍率。 |
| `roughness` | `number` | 必填 | Perlin 噪聲與簡諧頻率粗糙度（低值為地震波、高值為電擊／金屬抖動）。 |
| `fadeIn` | `number?` | `0` | 漸入秒數。 |
| `sustain` | `number?` | `0` | 峰值維持秒數。 |
| `fadeOut` | `number?` | `0.35` | 二次緩出淡出秒數。 |
| `posInfluence` | `Vector3?` | `Vector3.new(0.25, 0.25, 0.25)` | XYZ 位移權重（studs）。 |
| `rotInfluence` | `Vector3?` | `Vector3.new(1.2, 1.0, 1.8)` | Pitch/Yaw/Roll 旋轉權重（度）。 |
| `fovPunch` | `number?` | `0` | FOV 瞬間推拉值（負值內縮聚力、正值擴張衝擊，夾限於 `20 ~ 115`）。 |
| `maxDistance` | `number?` | `80` | 3D 空間衰減最大距離（studs）；有提供 `origin` 時依距離平方衰減。 |

### 2.2 `HitstopSpec`
| 欄位 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `duration` | `number` | 必填 | 頓幀／慢動作持續秒數。 |
| `timeScale` | `number?` | `0.02` | 時間縮放倍率（`0` 為完全靜止；`0.3 ~ 0.5` 為戲劇慢動作）。 |
| `affectAnimations` | `boolean?` | `true` | 是否暫調目標下所有 `Animator` 正在播放軌道的 `AdjustSpeed`。 |
| `affectParticles` | `boolean?` | `true` | 是否暫調目標下所有 `ParticleEmitter.TimeScale`。 |
| `applyToAttacker` | `boolean?` | `true` | `JuiceEngine.Play` 是否套用至 `context.attacker`。 |
| `applyToTarget` | `boolean?` | `true` | `JuiceEngine.Play` 是否套用至 `context.target`。 |

### 2.3 `HitFlashSpec`
| 欄位 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `flashColor` | `Color3?` | `Color3.new(1, 1, 1)` | 瞬間受擊峰值填色。 |
| `targetColor` | `Color3?` | 同 `flashColor` | 淡出階段過渡的目標色。 |
| `fillTransparency` | `number?` | `0.15` | 起始填色透明度。 |
| `endFillTransparency` | `number?` | `1` | 結束填色透明度。 |
| `outlineColor` | `Color3?` | `Color3.new(1, 1, 1)` | 外框輪廓色。 |
| `outlineTransparency` | `number?` | `0` | 起始外框透明度。 |
| `endOutlineTransparency` | `number?` | `1` | 結束外框透明度。 |
| `holdDuration` | `number?` | `0.03` | 峰值停留秒數。 |
| `duration` | `number?` | `0.18` | 總持續秒數（含 `holdDuration` 與漸變淡出）。 |
| `depthMode` | `Enum.HighlightDepthMode?` | `Occluded` | 遮蔽模式。 |

### 2.4 `SoundSpec`
| 欄位 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `id` | `string?` | 選填 | 識別名稱。 |
| `soundId` | `string` | 必填 | 僅限 Roblox 內建 `rbxasset://sounds/...` 或已驗證上傳資產。 |
| `group` | `string?` | `"default"` | 併發上限群組名。 |
| `maxConcurrent` | `number?` | `6` | 同群組最大同時播放數；超出時自動停止並回收最舊實例。 |
| `spatial` | `boolean?` | 依 `position` 自動判斷 | `true` 使用 `Workspace.Terrain` 3D `Attachment`；`false` 使用 `SoundService` 2D 資料夾。 |
| `volume` / `volumeRange` | `number?` / `RangeSpec?` | `0.7` | 音量或隨機音量區間。 |
| `pitchRange` | `RangeSpec?` | `{ 0.95, 1.05 }` | 隨機 `PlaybackSpeed` 區間。 |
| `rollOffMinDistance` / `rollOffMaxDistance` | `number?` | `10` / `85` | 3D 空間音衰減距離。 |
| `delay` | `number?` | `0` | 延遲觸發秒數。 |

### 2.5 `WorldBurstSpec` 與 `VFXTriggerSpec`
- **`WorldBurstSpec`**：包含 `particles: { BurstParticleSpec }?`、`light: WorldBurstLightSpec?`、`scale: number?`。每個 `BurstParticleSpec` 以 `Rate = 0` 並呼叫 `emitter:Emit(count)` 爆發，僅允許使用 `docs/VFX_ENGINE_SPEC.md` 第 6 節核准之 `rbxasset://textures/particles/...` 貼圖（或 `""`），`NumberSequence` / `ColorSequence` 上限 20 個 Keypoints，`PointLight.Range <= 60` 且 `Shadows = false`。
- **`VFXTriggerSpec`**：包含 `presetName?: string`、`mountIfMissing?: boolean`、`replayTimeline?: boolean`、`scale?: number`、`targetRole?: "attacker" | "target"`。透過 `ReplicatedStorage:FindFirstChild("VFXEngine")` 鬆耦合呼叫。

---

## 3. 公開 API（`ReplicatedStorage.JuiceEngine`）

```lua
local JuiceEngine = require(game.ReplicatedStorage.JuiceEngine)
```

| 函式簽名 | 說明 |
|---|---|
| `JuiceEngine.GetPreset(presetName: string, forceReload: boolean?): Types.JuicePreset?` | 讀取指定 Preset；`forceReload = true` 時繞過 `require` 快取熱重載。 |
| `JuiceEngine.ListPresets(): { string }` | 列出 `Presets/` 內所有可用 Preset 名稱（已排序）。 |
| `JuiceEngine.Play(presetOrName: string \| Types.JuicePreset, context: Types.PlayContext?): Types.JuiceHandle?` | 依 `PlayContext`（`position`, `cframe`, `attacker`, `target`, `targets`, `targetCharacter`, `vfxAura`, `intensity`, `scale`, `forceReload`）同步協調震動、頓幀、閃光、音效、爆發粒子與 `VFXEngine` 連動。 |
| `JuiceEngine.ShakeCamera(shakeSpec: Types.CameraShakeSpec, origin: Vector3?, maxDistance: number?, intensity: number?): Types.CameraShakeHandle` | 獨立觸發一次零漂移相機震動，支援距離衰減與中途平滑停止。 |
| `JuiceEngine.Hitstop(targets: { Model } \| Model, spec: Types.HitstopSpec)` | 獨立對單一或多個 `Model` 執行世代安全頓幀／慢動作。 |
| `JuiceEngine.FlashTarget(model: Model, spec: Types.HitFlashSpec)` | 獨立對目標 `Model` 執行物件池受擊閃光。 |
| `JuiceEngine.StopAll()` | 立即停止所有相機震動、還原所有頓幀速度、回收所有 `Highlight` 與音效／爆發粒子實例。 |

---

## 4. 效能與安全邊界（必讀）

1. **零漂移 RenderStep 雙段機制（`CameraShaker`）**：
   - `Enum.RenderPriority.Camera.Value - 1`（前置）：若上一幀有施加偏移，從 `workspace.CurrentCamera` 精確還原 `CFrame = CFrame * lastOffsetCFrame:Inverse()` 與 `FieldOfView -= lastFovDelta`（並核對 `camera == lastCamera`），確保 Roblox `Custom` 攝影機控制器永遠收到乾淨基準視角，**絕不累積旋轉或視角漂移**；閒置時自動 `UnbindFromRenderStep`。
   - `Enum.RenderPriority.Camera.Value + 10`（後置）：彙總所有啟用實例偏移後套用至攝影機並記錄當幀增量。
2. **Highlight 物件池上限 16**：
   - `HitFlashRunner` 嚴格限制最多建立 **16** 個 `Highlight` 實例，避免觸及 Roblox 全域 31 個 `Highlight` 渲染上限；池滿時自動回收最舊實例，同目標重疊受擊則直接複用原實例。
3. **頓幀安全不卡死（Per-Target Generation）**：
   - `HitstopController` 只在目標尚未處於頓幀時記錄真實 `track.Speed` 與 `emitter.TimeScale`，重疊觸發會遞增世代編號並取消舊計時器，目標離開 `DataModel` 或 `Humanoid.Died` 時立即還原速度。
4. **禁止編造數字 Asset ID 與 Studio GUI 外掛**：
   - 嚴禁編造任何未驗證之 `rbxassetid://<數字>`；內建粒子貼圖僅限 `docs/VFX_ENGINE_SPEC.md` 第 6 節核准清單，內建示範音效僅限 Roblox 客戶端 `rbxasset://sounds/...`（`swordslash.wav`、`swordlunge.wav`、`collide.wav`、`electronicpingshort.wav`、`uuhhh.mp3`）並以 `pcall` 安全播放。
   - 嚴禁建立任何 `DockWidgetPluginGui` 或 `PluginToolbar`。

---

## 5. 即時預覽控制（`JuicePreviewClient.client.luau`）

在 Play 模式中可透過 `Players.LocalPlayer` 的 Attributes 或快捷鍵即時測試：

### LocalPlayer Attributes
| Attribute 名稱 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `ActiveJuice` | `string` | `"HeavySlashHit"` | 目前選用的打擊感 Preset 名稱。 |
| `JuiceIntensity` | `number` | `1` | 整體強度倍率（縮放震動、FOV Punch、粒子數量與音量）。 |
| `JuiceTrigger` | `number` | `0` | 每次遞增即在角色前方 `4.5 studs` 與角色自身觸發一次完整打擊示範。 |
| `JuiceForceReload` | `boolean` | `false` | 設為 `true` 可於觸發時強制熱重載 Preset 模組。 |

### 預覽快捷鍵
- **`J`**：遞增 `JuiceTrigger`，立即觸發當前選用之打擊感 Preset。
- **`H`**：依序循環切換下一個 Juice Preset（更新 `ActiveJuice`）。
