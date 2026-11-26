# AtmosEngine 規格書（光影與氛圍管理引擎）

> **適用對象**：所有 AI 模型（Gemini、Claude）與人類開發者  
> **核心定位**：零成本、純 Luau 資料驅動之 Roblox 光影、大氣、後製與區域氛圍管理引擎，以標準化 Preset 資料表與執行期平滑補間引擎取代付費 Studio 外掛。

---

## 1. 對標原版插件功能對照表

本引擎將 Roblox 生態系兩款經典環境光影外掛——**Atmos**（天空盒與大氣光照預設庫）與 **Lighting Settings Saver**（一鍵快照備份與還原環境設定）——整合為純程式碼、無 Studio GUI 依賴的執行期引擎：

| 原版插件與功能 | AtmosEngine 對應模組 | 實作機制與強化項目 |
|---|---|---|
| **Atmos**：主題化天空與光影預設 | `Presets/*.luau` + `AtmosEngine.Apply` | 以 `--!strict` 資料表描述 `Lighting`、`Atmosphere`、`Sky` 與四大後製特效，並支援分類（`Day` / `Night` / `Sunset` / `Fantasy` / `Nature`）與熱重載。 |
| **Atmos**：無縫氣候 / 時段切換 | `Core/TransitionRunner.luau` | 基於 `RunService.Heartbeat` 與 `TweenService:GetValue` 的世代編號（Generation）可中斷平滑補間；`ClockTime` 自動走 24 小時最短路徑避免跨午夜閃爍。 |
| **Lighting Settings Saver**：Save Settings（儲存快照） | `Core/SnapshotManager.luau` (`CaptureSnapshot`) | 非破壞性擷取場景原始 `Lighting` 屬性、原 `Atmosphere`/`Sky`/後製特效參數，並自動排除 `__AtmosEngine_*` 受管實例。 |
| **Lighting Settings Saver**：Load / Restore（清除衝突並還原） | `Core/SnapshotManager.luau` (`Reset` / `RestoreImmediate`) | 套用預設時暫停未受管同名實例（記錄原 `Enabled` 或 `Sky`/`Atmosphere` 原 `Parent`），`Reset()` 結束後完整移除 `__AtmosEngine_*` 並無損還原原場景。 |
| **進階區域氛圍與日夜循環** | `Core/ZoneController.luau` | 支援多優先權（`priority`）定向包圍盒（`CFrame + Size` 或 `BasePart`）自動進出切換與基準還原；內建不與過渡衝突的日夜循環推進器。 |

---

## 2. Preset 資料結構 Schema（對應 `Core/Types.luau`）

所有 Preset 檔案須置於 `src/ReplicatedStorage/AtmosEngine/Presets/<PascalCaseName>.luau`，第一行必須為 `--!strict`，並回傳 `Types.AtmosPreset`：

```lua
--!strict
local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.AtmosPreset = {
	meta = {
		id = "PresetName",
		displayName = "顯示名稱",
		category = "Day", -- 選填："Day" | "Night" | "Sunset" | "Fantasy" | "Nature" 等
		author = "AtmosEngine",
		description = "光影風格說明",
		tags = { "tag1", "tag2" },
	},
	lighting = { ... },        -- 選填：Types.LightingSpec
	atmosphere = { ... },      -- 選填：Types.AtmosphereSpec
	sky = { ... },             -- 選填：Types.SkySpec
	bloom = { ... },           -- 選填：Types.BloomSpec
	colorCorrection = { ... }, -- 選填：Types.ColorCorrectionSpec
	depthOfField = { ... },    -- 選填：Types.DepthOfFieldSpec
	sunRays = { ... },         -- 選填：Types.SunRaysSpec
}

return Preset
```

### 2.1 `LightingSpec`（執行期安全屬性）
| 欄位 | 型別 | 說明 |
|---|---|---|
| `ClockTime` | `number?` | 時間（`0` ~ `24`），過渡時採 24 小時最短圓周路徑插值。 |
| `Brightness` | `number?` | 太陽光強度。 |
| `Ambient` | `Color3?` | 室內環境光色。 |
| `OutdoorAmbient` | `Color3?` | 戶外陰影處環境光色。 |
| `ColorShift_Top` | `Color3?` | 天空上方反射色偏。 |
| `ColorShift_Bottom` | `Color3?` | 地面下方反射色偏。 |
| `EnvironmentDiffuseScale` | `number?` | 環境漫反射倍率 `[0, 1]`。 |
| `EnvironmentSpecularScale` | `number?` | 環境鏡面反射倍率 `[0, 1]`。 |
| `ExposureCompensation` | `number?` | 曝光補償。 |
| `GeographicLatitude` | `number?` | 太陽傾角緯度。 |
| `ShadowSoftness` | `number?` | 陰影邊緣柔和度 `[0, 1]`。 |
| `GlobalShadows` | `boolean?` | 是否啟用全域陰影。 |
| `FogColor` / `FogStart` / `FogEnd` | `Color3?` / `number?` | 傳統霧效備援屬性（建議優先使用 `AtmosphereSpec`）。 |

### 2.2 `AtmosphereSpec`
| 欄位 | 型別 | 說明 |
|---|---|---|
| `Density` | `number?` | 大氣空氣密度（`0` ~ `1`）。 |
| `Offset` | `number?` | 遠景層偏移（`0` ~ `1`）。 |
| `Color` | `Color3?` | 散射基礎色調。 |
| `Decay` | `Color3?` | 遠距衰減色調。 |
| `Glare` | `number?` | 太陽周邊眩光強度。 |
| `Haze` | `number?` | 地平線霧靄厚度。 |

### 2.3 `SkySpec`
| 欄位 | 型別 | 說明 |
|---|---|---|
| `CelestialBodiesShown` | `boolean?` | 是否顯示太陽、月亮與星空。 |
| `SunAngularSize` | `number?` | 太陽視角大小。 |
| `MoonAngularSize` | `number?` | 月亮視角大小。 |
| `StarCount` | `number?` | 夜空星星數量（`0` ~ `5000`）。 |
| `SkyboxBk` / `Dn` / `Ft` / `Lf` / `Rt` / `Up` | `string?` | 選填天空盒六面貼圖（省略則保留原生預設天空貼圖）。 |
| `SunTextureId` / `MoonTextureId` | `string?` | 選填太陽／月亮貼圖（省略則使用原生星體）。 |

### 2.4 後製特效規格
- **`BloomSpec`**：`Enabled?: boolean`, `Intensity?: number`, `Size?: number`, `Threshold?: number`
- **`ColorCorrectionSpec`**：`Enabled?: boolean`, `Brightness?: number`, `Contrast?: number`, `Saturation?: number`, `TintColor?: Color3`
- **`DepthOfFieldSpec`**：`Enabled?: boolean`, `FarIntensity?: number`, `FocusDistance?: number`, `InFocusRadius?: number`, `NearIntensity?: number`
- **`SunRaysSpec`**：`Enabled?: boolean`, `Intensity?: number`, `Spread?: number`

---

## 3. 公開 API（`ReplicatedStorage.AtmosEngine`）

```lua
local AtmosEngine = require(game.ReplicatedStorage.AtmosEngine)
```

| 函式簽名 | 說明 |
|---|---|
| `AtmosEngine.GetPreset(presetName: string, forceReload: boolean?): AtmosPreset?` | 讀取指定 Preset；`forceReload = true` 時以暫存複製繞過 `require` 快取實現熱重載。 |
| `AtmosEngine.ListPresets(): { string }` | 列出 `Presets/` 內所有可用 Preset 名稱（已排序）。 |
| `AtmosEngine.CaptureSnapshot(): SnapshotData` | 手動擷取當前場景（不含 `__AtmosEngine_*`）的 `Lighting` 與後製狀態快照。 |
| `AtmosEngine.Apply(presetOrName: string \| AtmosPreset, options: ApplyOptions?): boolean` | 套用 Preset；若尚未擷取快照會先自動擷取。`options` 支援 `duration`、`easingStyle`、`easingDirection`、`forceReload`。 |
| `AtmosEngine.Reset(duration: number?)` | 以 `duration` 秒平滑過渡（預設 `0` 立即）還原至快照基準，清除 `__AtmosEngine_*` 並恢復原場景未受管實例。 |
| `AtmosEngine.SetDayNightCycle(enabled: boolean, speed: number?)` | 開啟或關閉日夜循環；`speed` 為每秒推進的小時數（預設 `0.25` 小時/秒）。過渡期間會自動讓渡 `ClockTime` 控制權。 |
| `AtmosEngine.RegisterZone(zoneConfig: ZoneConfig): () -> ()` | 註冊區域包圍盒（`part` 或 `cframe + size`），支援 `priority` 優先權與進出自動還原，回傳註銷函式。 |
| `AtmosEngine.ClearZones()` | 清除所有已註冊區域；若角色正位於區域內則平滑還原基準氛圍。 |
| `AtmosEngine.GetActivePresetName(): string?` | 取得目前作用中的 Preset 名稱；若未套用或已 `Reset` 則回傳 `nil`。 |

---

## 4. 效能與 Runtime 安全邊界（必讀）

1. **嚴禁於執行期寫入 `Lighting.Technology`**：
   Roblox 不允許在遊戲執行期（Runtime）修改 `Lighting.Technology`（寫入會直接拋出執行期錯誤）。`AtmosEngine` 在型別與執行期皆完全排除此屬性；建議在 **Roblox Studio 編輯期**預先將 `Lighting.Technology` 設為 `Enum.Technology.Future` 或 `Enum.Technology.ShadowMap` 以獲得最佳光影表現。
2. **禁止編造未驗證的數字 Asset ID**：
   嚴禁在任何 `.luau` 檔案中自行編造 `rbxassetid://<數字>`。預設 `SkySpec` 一律透過原生星體參數（`StarCount`、`SunAngularSize`、`MoonAngularSize`、`CelestialBodiesShown`）呈現天空與日夜星象；若有自訂天空盒需求，須填入經實際上傳驗證之資產 ID。
3. **非破壞性實例隔離**：
   所有執行期建立的 `Atmosphere`、`Sky`、`BloomEffect`、`ColorCorrectionEffect`、`DepthOfFieldEffect`、`SunRaysEffect` 皆統一命名為 `__AtmosEngine_*` 並標記 `AtmosEngineManaged = true` Attribute；原有場景內的同類實例僅被暫時停用／暫移，於 `Reset()` 後完整復原。
4. **世代編號取消（Generation Cancellation）**：
   連續快速切換 Preset 或進出重疊區域時，舊的補間流程會在下一個 `Heartbeat` 前立即失效並斷線，保證不會產生殘留寫入或閃爍。
5. **禁止 Studio GUI 外掛**：
   本引擎純以資料與 Luau API 運作，不建立任何 `DockWidgetPluginGui` 或 `PluginToolbar`。

---

## 5. 即時預覽控制（`AtmosPreviewClient.client.luau`）

在 Play 模式中可透過 `Players.LocalPlayer` 的 Attributes 或快捷鍵即時測試：

### LocalPlayer Attributes
| Attribute 名稱 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `ActiveAtmos` | `string` | `"None"` | 預設 `"None"` 不覆蓋原始場景；設為 Preset 名稱即平滑切換，設回 `"None"` 或 `"Reset"` 則還原原始光影。 |
| `AtmosTransitionDuration` | `number` | `1.2` | 切換與還原過渡秒數。 |
| `AtmosDayNightSpeed` | `number` | `0` | 日夜循環速度（小時/秒），`<= 0` 代表停用。 |
| `AtmosForceReload` | `boolean` | `false` | 設為 `true` 可於切換時強制熱重載 Preset 模組。 |

### 預覽快捷鍵
- **`L`**：依序循環切換所有氛圍預設（包含 `"None"` 還原原始光影）。
- **`N`**：開關日夜循環（開啟時預設設為 `0.25` 小時/秒，再次按下歸 `0` 關閉）。
