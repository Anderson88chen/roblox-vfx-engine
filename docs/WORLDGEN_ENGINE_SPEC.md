# WorldGenEngine 規格書（參數化幾何拼接、表面散布與懸索生成引擎）

> **適用對象**：所有 AI 模型（Gemini、Claude）與人類開發者  
> **核心定位**：零成本、純 Luau `--!strict` 資料驅動之 Roblox 參數化場景生成引擎，以原生幾何 `Part` / `WedgePart` / `PointLight` 程序化組裝建築圓弧、表面散布生態與懸鏈線索道，完全不依賴外部 `rbxassetid://` 或 Studio GUI 外掛。

---

## 1. 對標原版工具與架構對照表

| 對標原版 Roblox 插件 | WorldGenEngine 對應模組 | 實作機制與強化項目 |
|---|---|---|
| **Archimedes（v2 / v3）**：Edge/Pivot 旋轉拼接與螺旋增量 | `Core/ArchimedesBuilder.luau` | 實作精準**共邊樞紐（Edge-Hinge Pivot）**，支援 `Yaw` / `Pitch` / `Roll` 三軸、`Inner` / `Outer` / `Center` 樞紐側邊與 `spiralStep` 螺旋推進，以及 `BuildPolygonRing`（圓環底座、階梯圓台、柱列、雙柱拱門）。 |
| **Brushtool 2.1（XAXA）**：表面散布、法線對齊、隨機縮放旋轉 | `Core/PoissonScatterer.luau` | 以固定種子 `Random.new(seed)` 執行 **2D Bridson's Poisson-Disc Sampling**（`k = 20`），結合 `Workspace:Raycast` 往下投影、穿透透明／非實體裝飾物、坡度過濾（`minSlopeDegrees ~ maxSlopeDegrees`）、中心禁區 `clearRadius` 與法向量貼合比例 `alignToNormal`。 |
| **RopeMaster（XAXA）**：懸鏈線、垂度、切分與風格預設 | `Core/CatenaryBuilder.luau` | 以數值二分法求解雙曲餘弦 **Catenary (`cosh`)** 曲線（亦支援拋物線切換），依 `segments` 平滑切分繩段／交錯鎖鏈／霓虹電纜／藤蔓並附帶關節球，支援於節點 `t` 垂掛燈籠、能量晶體、霓虹／警示牌與藤蔓簇。 |

---

## 2. 核心幾何原理

### 2.1 共邊樞紐（Edge-Hinge Pivot）拼接演算法
傳統以零件中心點旋轉會產生扇形缺角或重疊。`ArchimedesBuilder` 改以**相鄰零件共享邊緣線**作為瞬時旋轉樞紐：
1. 依 `axis`（`Yaw` 繞 Y 軸於 XZ 平面轉向、推進沿 `-Z`；`Pitch` 繞 X 軸於 YZ 平面轉向、推進沿 `-Z`；`Roll` 繞 Z 軸於 XY 平面轉向、推進沿 `+X`）與 `angleDegrees` 正負號決定內側與外側邊界。
2. 取第 $i$ 塊零件前端對應 `hingeSide`（`"Inner"` / `"Outer"` / `"Center"`）之局部樞紐點 `frontHingeLocal`，變換為世界樞紐 `pivotWorld = currentCF * CFrame.new(frontHingeLocal)`。
3. 將樞紐旋轉 `angleRad` 並疊加軸向螺旋位移 `spiralStep`：`rotatedPivot = pivotWorld * rotCF * spiralCF`。
4. 再反向減去第 $i+1$ 塊零件後端對應的 `nextBackHingeLocal`，得出精準中心座標：`nextCF = rotatedPivot * CFrame.new(-nextBackHingeLocal)`。

### 2.2 2D Bridson's Poisson-Disc Sampling ＋ 地表投影
1. 在 `areaSize`（或 `radius`）區域內以最小間距 $r = \text{minDistance}$ 建立網格單元 $c = r / \sqrt{2}$，確保候選點之間距離必不小於 $r$，且避開中心禁區 `clearRadius`。
2. 每個有效樣本點以 `Workspace:Raycast` 向下投射，透過 `RaycastParams`（`Exclude`）自動排除所有玩家角色與 `Workspace.__WorldGenScenes`，並自動穿透 `CanCollide == false` 或 `Transparency >= 0.95` 的非實體裝飾物。
3. 計算命中面法向量與垂直軸夾角 $\theta = \arccos(\text{clamp}(N \cdot \hat{Y}, -1, 1))$，僅保留落於 `[minSlopeDegrees, maxSlopeDegrees]` 之點位，依 `alignToNormal`（`0..1`）線性插值直立軸與地表法線，再疊加隨機 Yaw 與微傾。

### 2.3 懸鏈線（Catenary `cosh`）二分求解
給定兩端點 $p_0, p_1$ 與垂度 `sag`：
- 水平跨距 $d = \|(p_1 - p_0)_{XZ}\|$，半跨距 $L_h = d / 2$。
- 透過 28 步二分法求解唯一懸鏈線參數 $a > 0$，滿足：
  $$a \left(\cosh\left(\frac{L_h}{a}\right) - 1\right) = \text{sag}$$
- 曲線上任一參數 $t \in [0, 1]$ 之位置為線性弦段 `p0:Lerp(p1, t)` 加上垂直懸垂偏移 $a(\cosh((t - 0.5)d/a) - \cosh(L_h/a))$，保證即使兩端高度不等仍能維持準確的 `sag` 垂度與自然重垂弧線。

---

## 3. Preset 資料結構 Schema（對應 `Core/Types.luau`）

所有 Preset 檔案必須置於 `src/ReplicatedStorage/WorldGenEngine/Presets/<PascalCaseName>.luau`，第一行必須為 `--!strict`，並回傳標註為 `Types.WorldScenePreset` 的資料表：

- **`WorldScenePreset`**：`meta`, `defaultSeed?`, `groundPad?`, `arcs?: { ArcSpec }`, `polygonRings?: { PolygonRingSpec }`, `scatters?: { ScatterSpec }`, `ropes?: { RopeSpec }`
- **`ArcSpec`**：`name?`, `origin?`, `partSize`, `axis?`（`"Yaw" | "Pitch" | "Roll"`）, `angleDegrees`, `count`, `hingeSide?`（`"Inner" | "Outer" | "Center"`）, `spiralStep?`, `sizeScalePerStep?`, `uniformScalePerStep?`, `material?`, `color?`, `alternateMaterial?`, `alternateColor?`, `addRimTrim?`, `trimColor?`, `trimMaterial?`
- **`PolygonRingSpec`**：`name?`, `center?`, `radius`, `count`, `mode?`（`"RingBase" | "Pillars" | "TwinArchPillars" | "SteppedRing"`）, `segmentSize?`, `pillarSize?`, `archWidth?`, `archHeight?`, `archThickness?`, `stepCount?`, `stepHeight?`, `stepInset?`, `faceCenter?`, `skipIndices?`, `addPillarCap?`, `addPillarLight?`, `lightColor?`, `lightRange?`, `lightBrightness?`
- **`ScatterSpec`**：`name?`, `origin?`, `areaSize?`, `radius?`, `minDistance`, `seed?`, `kAttempts?`（預設 `20`）, `maxInstances?`, `clearRadius?`, `minSlopeDegrees?`, `maxSlopeDegrees?`, `alignToNormal?`, `scaleRange?`, `tiltRangeDegrees?`, `fallbackToOriginPlane?`, `templates: { ScatterAssetTemplate }`
  - 支援 `kind`：`"CrystalCluster" | "StonePillar" | "StylizedShrub" | "FloatingRune" | "NeonCrate" | "MossBoulder" | "RunicObelisk"`
- **`RopeSpec`**：`name?`, `p0`, `p1`, `sag?`, `segments?`, `thickness?`, `style?`（`"Rope" | "Chain" | "NeonCable" | "Vine"`）, `useCosh?`, `addJoints?`, `hangingProps?: { HangingPropSpec }`
  - `HangingPropSpec.kind`：`"Lantern" | "EnergyCrystal" | "WarningSign" | "NeonSign" | "VineCluster"`

---

## 4. 公開 API（`ReplicatedStorage.WorldGenEngine`）

```lua
local WorldGenEngine = require(game.ReplicatedStorage.WorldGenEngine)
```

| 函式簽名 | 說明 |
|---|---|
| `WorldGenEngine.GetPreset(presetName: string, forceReload: boolean?): Types.WorldScenePreset?` | 讀取場景 Preset；`forceReload = true` 時繞過 `require` 快取熱重載。 |
| `WorldGenEngine.ListPresets(): { string }` | 列出 `Presets/` 內所有可用 Preset 名稱（已排序）。 |
| `WorldGenEngine.BuildScene(presetOrName: string \| Types.WorldScenePreset, options: Types.BuildOptions?): Types.WorldSceneHandle?` | 依 `BuildOptions`（`origin`、`seed`、`scale`、`clearPrevious`、`batchSize`）批次離線組裝並掛載至 `Workspace.__WorldGenScenes`。 |
| `WorldGenEngine.BuildArc(spec: Types.ArcSpec, parent: Instance?): Model` | 單獨生成 Archimedes 共邊樞紐弧線／螺旋結構。 |
| `WorldGenEngine.BuildPolygonRing(spec: Types.PolygonRingSpec, parent: Instance?): Model` | 單獨生成多邊形圓環／階梯／柱列／雙柱拱門。 |
| `WorldGenEngine.Scatter(spec: Types.ScatterSpec, parent: Instance?): Model` | 單獨執行 2D 泊松盤地表投影散布。 |
| `WorldGenEngine.BuildRope(spec: Types.RopeSpec, parent: Instance?): Model` | 單獨生成 Catenary 懸索與垂掛物。 |
| `WorldGenEngine.Clear(handleOrId: (Types.WorldSceneHandle \| string)?)` | 清除指定場景 Handle、ID 或 Preset 名稱之生成物；傳入 `nil` 等同 `ClearAll()`。 |
| `WorldGenEngine.ClearAll()` | 清除所有受控與殘留於 `Workspace.__WorldGenScenes` 的場景物件。 |
| `WorldGenEngine.GetActiveSceneNames(): { string }` | 回傳目前存在於場景中的已生成 Preset 名稱清單。 |

---

## 5. 效能預算與安全邊界

1. **批次離線組裝**：所有零件屬性於掛載進 `Workspace` 前完全於離線容器設定完成，並依區域每批 `<= 250` 個 `BasePart` 封裝掛載至 `Workspace.__WorldGenScenes`，大幅降低同步與渲染開銷。
2. **光源安全上限**：所有程序化生成之 `PointLight` 嚴格夾限 `Range <= 60` 且強制 `Shadows = false`。
3. **零外部 Asset ID**：嚴禁編造任何未驗證的 `rbxassetid://<數字>`，全部物件以原生 `Part` / `WedgePart` 組裝。
4. **唯讀紅線與禁止外掛**：嚴禁修改 `VFXEngine` 核心與 `VFXPreviewClient.client.luau`，亦嚴禁建立任何 Studio Plugin GUI（`DockWidgetPluginGui` / `CreateToolbar`）。
5. **防 Z-Fighting 幾何微偏移規範**：
   - **3-Coloring 閉合環微差**（`ZFIGHT_EPS = 0.005`）：`RingBase` / `SteppedRing` / `TwinArchPillars` 透過 `ringCycleLayer` 確保任意邊數閉合環的相鄰扇段在高度與徑向厚度上保有 `0.005 ~ 0.01` studs 錯位；`BuildArc` 亦於非推進截面施加循環微差。
   - **接地微下沉**（`GROUND_SINK = 0.02`）：實體底座、石階、散落物件基座與 `GroundPad` 底面微幅下沉埋入地表（非碰撞發光環則微抬），上下層階梯與柱體接合處亦彼此嵌入 `0.02` studs，消除與 `Baseplate` 或鄰層頂面的共面閃爍。
   - **懸索奇偶截面錯位**：`CatenaryBuilder` 對相鄰交疊繩段施加正負 `0.005` studs 的奇偶截面微差，避免在鉛垂平面上產生側面 Z-Fighting。

---

## 6. 即時預覽控制（`WorldGenPreviewClient.client.luau`）

在 Play 模式中預設不自動生成場景（`ActiveWorldScene = "None"`），可透過 `Players.LocalPlayer` Attributes 或快捷鍵即時切換測試：

### LocalPlayer Attributes
| Attribute 名稱 | 型別 | 預設值 | 說明 |
|---|---|---|---|
| `ActiveWorldScene` | `string` | `"None"` | 設定為 Preset 名稱（如 `"AstralSanctuaryArena"`）即以玩家前方／腳下基準生成；設回 `"None"` 則清除。 |
| `WorldSeed` | `number` | `42` | 控制 `PoissonScatterer` 之固定隨機種子。 |
| `WorldOriginOffset` | `Vector3` | `Vector3.zero` | 相對於玩家基準座標系之生成位置偏移。 |
| `WorldGenForceReload` | `boolean` | `false` | 設為 `true` 可於切換時強制熱重載 Preset 模組。 |

### 預覽快捷鍵
- **`G`**：循環切換預覽場景：`"AstralSanctuaryArena"` → `"CyberpunkAlleyway"` → `"MistyStoneRuins"` → `"None"`（清除所有預覽生成物）。
