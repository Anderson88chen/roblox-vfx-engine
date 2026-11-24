#!/usr/bin/env python3
"""
VFXEngine 離線程序化去背貼圖生成器（Pillow + NumPy）

專為 Roblox ParticleEmitter / Beam / Trail 設計，產出純白 RGB (255, 255, 255)
搭配平滑 Alpha 遮罩通道的 RGBA PNG 貼圖，方便在 Roblox 中直接透過
ColorSequence 染出任意漸層色彩，且邊緣皆柔化歸零不裁切。

使用範例：
    python tools/vfx_texture_gen.py all
    python tools/vfx_texture_gen.py radial --size 512 --rays 4 --out tools/output/star_flare.png
    python tools/vfx_texture_gen.py smoke --size 512 --octaves 5 --seed 7 --out tools/output/fbm_smoke.png
    python tools/vfx_texture_gen.py circle --size 512 --sides 6 --rings 3 --ticks 24 --inner-star --out tools/output/magic_circle.png
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Tuple

import numpy as np
from PIL import Image


DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "output"


def parse_hex_color(hex_str: str) -> Tuple[int, int, int]:
    cleaned = hex_str.strip().lstrip("#")
    if len(cleaned) != 6:
        raise ValueError(f"顏色格式錯誤 '{hex_str}'，請使用 #RRGGBB 六位十六進位色碼。")
    return (
        int(cleaned[0:2], 16),
        int(cleaned[2:4], 16),
        int(cleaned[4:6], 16),
    )


def save_rgba_png(alpha: np.ndarray, tint: Tuple[int, int, int], out_path: Path) -> Path:
    """將 [0, 1] 浮點 Alpha 陣列封裝為固定純白（或指定色）RGBA PNG 並儲存。"""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    alpha_clamped = np.clip(alpha, 0.0, 1.0)
    alpha_u8 = np.rint(alpha_clamped * 255.0).astype(np.uint8)

    h, w = alpha_u8.shape
    rgba = np.empty((h, w, 4), dtype=np.uint8)
    rgba[..., 0] = tint[0]
    rgba[..., 1] = tint[1]
    rgba[..., 2] = tint[2]
    rgba[..., 3] = alpha_u8

    img = Image.fromarray(rgba, mode="RGBA")
    img.save(out_path, format="PNG")
    return out_path


def make_normalized_grid(size: int) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """回傳座標 (x, y) ∈ [-1, 1]、半徑 r 與角度 theta。"""
    coords = np.linspace(-1.0, 1.0, size, dtype=np.float32)
    x, y = np.meshgrid(coords, coords)
    r = np.sqrt(x * x + y * y)
    theta = np.arctan2(y, x)
    return x, y, r, theta


def smooth_edge_fade(r: np.ndarray, fade_start: float = 0.85, fade_end: float = 1.0) -> np.ndarray:
    t = np.clip((fade_end - r) / max(1e-5, fade_end - fade_start), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def generate_radial_alpha(
    size: int,
    falloff: float = 2.2,
    core_boost: float = 0.35,
    rays: int = 0,
    ray_strength: float = 0.5,
    ring_radius: float = 0.0,
    ring_width: float = 0.04,
) -> np.ndarray:
    _, _, r, theta = make_normalized_grid(size)

    radial_base = np.clip(1.0 - r, 0.0, 1.0) ** falloff
    core = core_boost * np.exp(-16.0 * (r * r))
    alpha = radial_base + core

    if rays > 0 and ray_strength > 0.0:
        # 透過高次冪餘弦產生銳利對稱星芒
        ray_wave = np.abs(np.cos(0.5 * rays * theta)) ** 18.0
        ray_decay = np.exp(-3.5 * r)
        alpha = alpha + ray_strength * ray_wave * ray_decay

    if ring_radius > 0.0 and ring_width > 0.0:
        ring = np.exp(-(((r - ring_radius) / ring_width) ** 2))
        alpha = np.maximum(alpha, ring * 0.9)

    alpha = alpha * smooth_edge_fade(r, 0.86, 1.0)
    return np.clip(alpha, 0.0, 1.0)


def _perlin_2d_periodic(size: int, period: int, rng: np.random.Generator) -> np.ndarray:
    """向量化 2D 週期性梯度（Perlin）雜訊，回傳近似 [-1, 1]。"""
    angles = rng.uniform(0.0, 2.0 * np.pi, size=(period, period)).astype(np.float32)
    grad_x = np.cos(angles)
    grad_y = np.sin(angles)

    lin = np.linspace(0.0, float(period), size, endpoint=False, dtype=np.float32)
    gx, gy = np.meshgrid(lin, lin)

    x0 = np.floor(gx).astype(np.int32)
    y0 = np.floor(gy).astype(np.int32)
    dx = gx - x0
    dy = gy - y0

    x0m = x0 % period
    y0m = y0 % period
    x1m = (x0 + 1) % period
    y1m = (y0 + 1) % period

    n00 = grad_x[y0m, x0m] * dx + grad_y[y0m, x0m] * dy
    n10 = grad_x[y0m, x1m] * (dx - 1.0) + grad_y[y0m, x1m] * dy
    n01 = grad_x[y1m, x0m] * dx + grad_y[y1m, x0m] * (dy - 1.0)
    n11 = grad_x[y1m, x1m] * (dx - 1.0) + grad_y[y1m, x1m] * (dy - 1.0)

    # Quintic fade
    u = dx * dx * dx * (dx * (dx * 6.0 - 15.0) + 10.0)
    v = dy * dy * dy * (dy * (dy * 6.0 - 15.0) + 10.0)

    nx0 = n00 + u * (n10 - n00)
    nx1 = n01 + u * (n11 - n01)
    val = nx0 + v * (nx1 - nx0)
    return val * 1.4142135


def generate_fbm_smoke_alpha(
    size: int,
    octaves: int = 5,
    scale: float = 4.0,
    persistence: float = 0.5,
    lacunarity: float = 2.0,
    seed: int = 42,
    edge_power: float = 1.6,
) -> np.ndarray:
    rng = np.random.default_rng(seed)
    total = np.zeros((size, size), dtype=np.float32)
    amplitude = 1.0
    max_amp = 0.0
    freq = max(1.0, scale)

    for _ in range(max(1, octaves)):
        period = max(2, int(round(freq)))
        total += _perlin_2d_periodic(size, period, rng) * amplitude
        max_amp += amplitude
        amplitude *= persistence
        freq *= lacunarity

    raw_norm = total / max(1e-5, max_amp)
    lo = float(np.percentile(raw_norm, 5.0))
    hi = float(np.percentile(raw_norm, 98.0))
    fbm = np.clip((raw_norm - lo) / max(1e-5, hi - lo), 0.0, 1.0)

    _, _, r, _ = make_normalized_grid(size)
    radial_mask = (np.clip(1.0 - r * r, 0.0, 1.0) ** edge_power) * smooth_edge_fade(r, 0.85, 1.0)
    return np.clip(fbm * radial_mask, 0.0, 1.0)


def _segment_distance(
    px: np.ndarray,
    py: np.ndarray,
    ax: float,
    ay: float,
    bx: float,
    by: float,
) -> np.ndarray:
    vx = bx - ax
    vy = by - ay
    denom = vx * vx + vy * vy
    if denom < 1e-8:
        return np.sqrt((px - ax) ** 2 + (py - ay) ** 2)
    t = np.clip(((px - ax) * vx + (py - ay) * vy) / denom, 0.0, 1.0)
    cx = ax + t * vx
    cy = ay + t * vy
    return np.sqrt((px - cx) ** 2 + (py - cy) ** 2)


def generate_magic_circle_alpha(
    size: int,
    sides: int = 6,
    rings: int = 3,
    ticks: int = 24,
    inner_star: bool = True,
    line_width: float = 0.008,
    glow_radius: float = 0.025,
) -> np.ndarray:
    x, y, r, theta = make_normalized_grid(size)
    dist = np.full((size, size), 10.0, dtype=np.float32)

    # 1. 同心圓環
    outer_r = 0.86
    ring_count = max(1, rings)
    ring_radii = np.linspace(0.38, outer_r, ring_count)
    for idx, radius in enumerate(ring_radii):
        thickness_bias = 0.004 if idx == ring_count - 1 else 0.0
        d_ring = np.maximum(0.0, np.abs(r - float(radius)) - thickness_bias)
        dist = np.minimum(dist, d_ring)

    # 2. 外環雙層細線裝飾
    dist = np.minimum(dist, np.abs(r - (outer_r - 0.06)))

    # 3. 幾何刻度線
    if ticks > 0:
        tick_sector = (2.0 * np.pi) / float(ticks)
        angle_mod = np.mod(theta + np.pi, tick_sector) - 0.5 * tick_sector
        # 離散角距離轉為弧長距離
        arc_dist = np.abs(r * np.sin(angle_mod))
        r_inner = outer_r - 0.06
        r_outer = outer_r
        in_band = (r >= r_inner) & (r <= r_outer)
        tick_radial_dist = np.where(
            in_band,
            0.0,
            np.minimum(np.abs(r - r_inner), np.abs(r - r_outer)),
        )
        d_ticks = np.sqrt(arc_dist * arc_dist + tick_radial_dist * tick_radial_dist)
        dist = np.minimum(dist, d_ticks)

    # 4. 正多邊形邊框與星陣連線
    n_sides = max(3, sides)
    poly_r = outer_r - 0.075
    angles = np.linspace(0.0, 2.0 * np.pi, n_sides, endpoint=False) - 0.5 * np.pi
    vx = poly_r * np.cos(angles)
    vy = poly_r * np.sin(angles)

    for i in range(n_sides):
        j = (i + 1) % n_sides
        d_edge = _segment_distance(x, y, float(vx[i]), float(vy[i]), float(vx[j]), float(vy[j]))
        dist = np.minimum(dist, d_edge)

        # 頂點符文小圓圈
        node_d = np.abs(np.sqrt((x - float(vx[i])) ** 2 + (y - float(vy[i])) ** 2) - 0.032)
        dist = np.minimum(dist, node_d)

    if inner_star and n_sides >= 4:
        step = 2 if n_sides >= 5 else 1
        if n_sides == 6:
            # 六芒星：兩組隔點三角形
            for i in range(6):
                j = (i + 2) % 6
                d_star = _segment_distance(x, y, float(vx[i]), float(vy[i]), float(vx[j]), float(vy[j]))
                dist = np.minimum(dist, d_star)
        else:
            for i in range(n_sides):
                j = (i + step) % n_sides
                d_star = _segment_distance(x, y, float(vx[i]), float(vy[i]), float(vx[j]), float(vy[j]))
                dist = np.minimum(dist, d_star)

        # 核心內星小圓
        dist = np.minimum(dist, np.abs(r - 0.16))

    # 反鋸齒核心線條 + 柔和光暈
    aa = max(1.5 / float(size), line_width * 0.35)
    core_line = np.clip(1.0 - (dist - line_width) / aa, 0.0, 1.0)
    glow = 0.55 * np.exp(-((dist / max(1e-4, glow_radius)) ** 2))
    alpha = np.maximum(core_line, glow)

    alpha = alpha * smooth_edge_fade(r, 0.90, 0.99)
    return np.clip(alpha, 0.0, 1.0)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="VFXEngine 程序化去背貼圖生成器（純白 RGB + Alpha PNG）",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # radial
    p_rad = sub.add_parser("radial", help="生成徑向光暈 / 星芒貼圖")
    p_rad.add_argument("--size", type=int, default=512, help="輸出尺寸（正方形像素，預設 512）")
    p_rad.add_argument("--falloff", type=float, default=2.2, help="徑向衰減指數（預設 2.2）")
    p_rad.add_argument("--core-boost", type=float, default=0.35, help="中心高光強度（預設 0.35）")
    p_rad.add_argument("--rays", type=int, default=0, help="星芒射線數量（預設 0 不啟用）")
    p_rad.add_argument("--ray-strength", type=float, default=0.5, help="星芒射線亮度（預設 0.5）")
    p_rad.add_argument("--ring-radius", type=float, default=0.0, help="外環半徑 0~1（預設 0 不啟用）")
    p_rad.add_argument("--ring-width", type=float, default=0.04, help="外環寬度（預設 0.04）")
    p_rad.add_argument("--tint", type=str, default="#FFFFFF", help="RGB 色碼（預設 #FFFFFF 利於引擎染色）")
    p_rad.add_argument("--out", type=Path, default=DEFAULT_OUTPUT_DIR / "radial_glow.png")

    # smoke
    p_smk = sub.add_parser("smoke", help="生成多八度 FBM 能量煙霧貼圖")
    p_smk.add_argument("--size", type=int, default=512, help="輸出尺寸（預設 512）")
    p_smk.add_argument("--octaves", type=int, default=5, help="FBM 疊代層數（預設 5）")
    p_smk.add_argument("--scale", type=float, default=4.0, help="基礎雜訊頻率（預設 4.0）")
    p_smk.add_argument("--persistence", type=float, default=0.5, help="振幅衰減係數（預設 0.5）")
    p_smk.add_argument("--lacunarity", type=float, default=2.0, help="頻率倍增係數（預設 2.0）")
    p_smk.add_argument("--seed", type=int, default=42, help="隨機種子（預設 42）")
    p_smk.add_argument("--edge-power", type=float, default=1.6, help="邊緣徑向淡出指數（預設 1.6）")
    p_smk.add_argument("--tint", type=str, default="#FFFFFF", help="RGB 色碼（預設 #FFFFFF）")
    p_smk.add_argument("--out", type=Path, default=DEFAULT_OUTPUT_DIR / "fbm_smoke.png")

    # circle
    p_cir = sub.add_parser("circle", help="生成對稱幾何魔法陣貼圖")
    p_cir.add_argument("--size", type=int, default=512, help="輸出尺寸（預設 512）")
    p_cir.add_argument("--sides", type=int, default=6, help="對稱邊數（預設 6）")
    p_cir.add_argument("--rings", type=int, default=3, help="同心圓環數（預設 3）")
    p_cir.add_argument("--ticks", type=int, default=24, help="外圈刻度數量（預設 24）")
    p_cir.add_argument("--inner-star", action="store_true", help="啟用內部多邊星陣連線")
    p_cir.add_argument("--line-width", type=float, default=0.008, help="線條正規化寬度（預設 0.008）")
    p_cir.add_argument("--glow-radius", type=float, default=0.025, help="線條柔光半徑（預設 0.025）")
    p_cir.add_argument("--tint", type=str, default="#FFFFFF", help="RGB 色碼（預設 #FFFFFF）")
    p_cir.add_argument("--out", type=Path, default=DEFAULT_OUTPUT_DIR / "magic_circle.png")

    # all
    p_all = sub.add_parser("all", help="一次生成全套 4 張基礎 VFX 貼圖至輸出資料夾")
    p_all.add_argument("--size", type=int, default=512, help="輸出尺寸（預設 512）")
    p_all.add_argument("--out-dir", type=Path, default=DEFAULT_OUTPUT_DIR, help="輸出目錄")
    p_all.add_argument("--tint", type=str, default="#FFFFFF", help="RGB 色碼（預設 #FFFFFF）")

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    tint = parse_hex_color(args.tint)

    if args.command == "radial":
        alpha = generate_radial_alpha(
            size=args.size,
            falloff=args.falloff,
            core_boost=args.core_boost,
            rays=args.rays,
            ray_strength=args.ray_strength,
            ring_radius=args.ring_radius,
            ring_width=args.ring_width,
        )
        saved = save_rgba_png(alpha, tint, args.out)
        print(f"Generated: {saved}")

    elif args.command == "smoke":
        alpha = generate_fbm_smoke_alpha(
            size=args.size,
            octaves=args.octaves,
            scale=args.scale,
            persistence=args.persistence,
            lacunarity=args.lacunarity,
            seed=args.seed,
            edge_power=args.edge_power,
        )
        saved = save_rgba_png(alpha, tint, args.out)
        print(f"Generated: {saved}")

    elif args.command == "circle":
        alpha = generate_magic_circle_alpha(
            size=args.size,
            sides=args.sides,
            rings=args.rings,
            ticks=args.ticks,
            inner_star=args.inner_star,
            line_width=args.line_width,
            glow_radius=args.glow_radius,
        )
        saved = save_rgba_png(alpha, tint, args.out)
        print(f"Generated: {saved}")

    elif args.command == "all":
        out_dir: Path = args.out_dir
        jobs = [
            (
                out_dir / "radial_glow.png",
                generate_radial_alpha(size=args.size, falloff=2.4, core_boost=0.45),
            ),
            (
                out_dir / "star_flare.png",
                generate_radial_alpha(
                    size=args.size, falloff=2.6, core_boost=0.5, rays=4, ray_strength=0.65
                ),
            ),
            (
                out_dir / "fbm_smoke.png",
                generate_fbm_smoke_alpha(
                    size=args.size, octaves=5, scale=4.0, seed=42, edge_power=1.6
                ),
            ),
            (
                out_dir / "magic_circle.png",
                generate_magic_circle_alpha(
                    size=args.size, sides=6, rings=3, ticks=24, inner_star=True
                ),
            ),
        ]
        for target, alpha in jobs:
            saved = save_rgba_png(alpha, tint, target)
            print(f"Generated: {saved}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
