#!/usr/bin/env python3
"""Static compliance and structural verification for all Roblox declarative engines."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "src"
PROJECT_JSON = ROOT / "default.project.json"

LOCKED_VFX_FILES = [
    "src/ReplicatedStorage/VFXEngine/init.luau",
    "src/StarterPlayer/StarterPlayerScripts/VFXPreviewClient.client.luau",
]
LOCKED_VFX_PREFIX = "src/ReplicatedStorage/VFXEngine/Core/"

FORBIDDEN_PATTERNS = [
    ("DockWidgetPluginGui", re.compile(r"\bDockWidgetPluginGui\b")),
    ("CreateToolbar", re.compile(r"\bCreateToolbar\b")),
    ("PluginToolbar", re.compile(r"\bPluginToolbar\b")),
    ("Lighting.Technology write", re.compile(r"Lighting\s*\.\s*Technology\s*=")),
    ("Fabricated numeric rbxassetid", re.compile(r"rbxassetid://\d+")),
]

NEW_ENGINES = [
    ("AtmosEngine", "AtmosPreviewClient.client.luau", "ATMOS_ENGINE_SPEC.md"),
    ("JuiceEngine", "JuicePreviewClient.client.luau", "JUICE_ENGINE_SPEC.md"),
    ("CinemaEngine", "CinemaPreviewClient.client.luau", "CINEMA_ENGINE_SPEC.md"),
    ("WorldGenEngine", "WorldGenPreviewClient.client.luau", "WORLDGEN_ENGINE_SPEC.md"),
]

REQUIRE_SCRIPT_RE = re.compile(r"\brequire\s*\(\s*(script(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\s*\)")


def strip_luau_comments_and_strings(source: str) -> str:
    """Replace Luau comments and strings with spaces to preserve line structure safely."""
    out: list[str] = []
    i = 0
    n = len(source)

    while i < n:
        ch = source[i]

        # Long comment --[=*[ ... ]=*]
        if source.startswith("--[", i):
            eq_end = i + 3
            while eq_end < n and source[eq_end] == "=":
                eq_end += 1
            if eq_end < n and source[eq_end] == "[":
                eq_count = eq_end - (i + 3)
                close_tag = "]" + ("=" * eq_count) + "]"
                end_idx = source.find(close_tag, eq_end + 1)
                if end_idx == -1:
                    break
                for c in source[i : end_idx + len(close_tag)]:
                    out.append("\n" if c == "\n" else " ")
                i = end_idx + len(close_tag)
                continue

        # Single-line comment --
        if source.startswith("--", i):
            nl = source.find("\n", i)
            if nl == -1:
                break
            out.append("\n")
            i = nl + 1
            continue

        # Long string [=*[ ... ]=*]
        if ch == "[":
            eq_end = i + 1
            while eq_end < n and source[eq_end] == "=":
                eq_end += 1
            if eq_end < n and source[eq_end] == "[":
                eq_count = eq_end - (i + 1)
                close_tag = "]" + ("=" * eq_count) + "]"
                end_idx = source.find(close_tag, eq_end + 1)
                if end_idx == -1:
                    raise ValueError(f"Unclosed long string starting at offset {i}")
                for c in source[i : end_idx + len(close_tag)]:
                    out.append("\n" if c == "\n" else " ")
                i = end_idx + len(close_tag)
                continue

        # Quoted string "..." or '...'
        if ch in ('"', "'"):
            quote = ch
            j = i + 1
            while j < n:
                if source[j] == "\\":
                    j += 2
                    continue
                if source[j] == quote:
                    j += 1
                    break
                j += 1
            for c in source[i:j]:
                out.append("\n" if c == "\n" else " ")
            i = j
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def check_bracket_balance(cleaned: str, rel_path: str) -> list[str]:
    pairs = {"(": ")", "{": "}", "[": "]"}
    closing = {")": "(", "}": "{", "]": "["}
    stack: list[tuple[str, int]] = []
    errors: list[str] = []
    line = 1

    for ch in cleaned:
        if ch == "\n":
            line += 1
        elif ch in pairs:
            stack.append((ch, line))
        elif ch in closing:
            if not stack:
                errors.append(f"{rel_path}:{line}: unmatched '{ch}'")
            else:
                top_ch, top_line = stack.pop()
                if pairs[top_ch] != ch:
                    errors.append(
                        f"{rel_path}:{line}: expected '{pairs[top_ch]}' for '{top_ch}' at line {top_line}, got '{ch}'"
                    )

    for top_ch, top_line in stack:
        errors.append(f"{rel_path}:{top_line}: unclosed '{top_ch}'")

    return errors


def resolve_script_require(file_path: Path, expr: str) -> Path | None:
    parts = expr.split(".")[1:]  # skip "script"
    # In Rojo: init.luau represents the directory itself; other *.luau are leaf modules
    curr = file_path.parent if file_path.name == "init.luau" else file_path

    for part in parts:
        if part == "Parent":
            curr = curr.parent
        else:
            if curr.is_file():
                curr = curr.parent
            candidate_file = curr / f"{part}.luau"
            candidate_dir = curr / part
            if candidate_file.is_file():
                curr = candidate_file
            elif (candidate_dir / "init.luau").is_file():
                curr = candidate_dir / "init.luau"
            elif candidate_dir.is_dir():
                curr = candidate_dir
            else:
                return None

    if curr.is_dir() and (curr / "init.luau").is_file():
        return curr / "init.luau"
    if curr.is_file():
        return curr
    return None


def check_readonly_vfx() -> tuple[bool, list[str]]:
    errors: list[str] = []
    for cmd in (["git", "status", "--porcelain"], ["git", "diff", "--name-only"]):
        res = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=False)
        if res.returncode != 0:
            errors.append(f"Command {' '.join(cmd)} failed: {res.stderr.strip()}")
            continue
        for raw_line in res.stdout.splitlines():
            path_part = raw_line[3:].strip() if cmd[1] == "status" else raw_line.strip()
            path_norm = path_part.replace("\\", "/").strip('"')
            if " -> " in path_norm:
                path_norm = path_norm.split(" -> ")[-1].strip('"')
            if path_norm in LOCKED_VFX_FILES or path_norm.startswith(LOCKED_VFX_PREFIX):
                errors.append(f"Locked VFXEngine file modified: {path_norm}")
    return (len(errors) == 0, errors)


def main() -> int:
    luau_files = sorted(SRC_DIR.rglob("*.luau"))
    failures: list[str] = []

    # 1. Read-only lock check
    ok_lock, lock_errors = check_readonly_vfx()
    if ok_lock:
        print("[PASS] 1. Read-only VFXEngine lock check: 0 locked files modified.")
    else:
        print("[FAIL] 1. Read-only VFXEngine lock check:")
        for err in lock_errors:
            print(f"  - {err}")
        failures.extend(lock_errors)

    # 2. Zero Studio GUI & forbidden patterns check
    gui_errors: list[str] = []
    strict_errors: list[str] = []
    asset_errors: list[str] = []
    bracket_errors: list[str] = []
    require_errors: list[str] = []
    require_count = 0

    for file_path in luau_files:
        rel_path = file_path.relative_to(ROOT).as_posix()
        text = file_path.read_text(encoding="utf-8")
        lines = text.splitlines()

        if not lines or lines[0].strip() != "--!strict":
            strict_errors.append(f"{rel_path}: first line is not '--!strict'")

        for label, pattern in FORBIDDEN_PATTERNS:
            for match in pattern.finditer(text):
                line_no = text.count("\n", 0, match.start()) + 1
                msg = f"{rel_path}:{line_no}: forbidden pattern '{label}' ({match.group(0)})"
                if label == "Fabricated numeric rbxassetid":
                    asset_errors.append(msg)
                else:
                    gui_errors.append(msg)

        try:
            cleaned = strip_luau_comments_and_strings(text)
        except ValueError as exc:
            bracket_errors.append(f"{rel_path}: {exc}")
            continue

        bracket_errors.extend(check_bracket_balance(cleaned, rel_path))

        for match in REQUIRE_SCRIPT_RE.finditer(cleaned):
            require_count += 1
            expr = match.group(1)
            resolved = resolve_script_require(file_path, expr)
            if resolved is None:
                line_no = cleaned.count("\n", 0, match.start()) + 1
                require_errors.append(f"{rel_path}:{line_no}: unresolved require({expr})")

    if not gui_errors:
        print(f"[PASS] 2. Zero Studio GUI & runtime-forbidden API check ({len(luau_files)} .luau files).")
    else:
        print("[FAIL] 2. Zero Studio GUI & runtime-forbidden API check:")
        for err in gui_errors:
            print(f"  - {err}")
        failures.extend(gui_errors)

    if not strict_errors and not asset_errors:
        print(f"[PASS] 3. '--!strict' header & zero fabricated rbxassetid:// check ({len(luau_files)} .luau files).")
    else:
        print("[FAIL] 3. '--!strict' header & zero fabricated rbxassetid:// check:")
        for err in strict_errors + asset_errors:
            print(f"  - {err}")
        failures.extend(strict_errors + asset_errors)

    if not bracket_errors and not require_errors:
        print(
            f"[PASS] 4. Bracket balance & static require(script...) resolution check "
            f"({len(luau_files)} files, {require_count} requires)."
        )
    else:
        print("[FAIL] 4. Bracket balance & static require(script...) resolution check:")
        for err in bracket_errors + require_errors:
            print(f"  - {err}")
        failures.extend(bracket_errors + require_errors)

    # 5. default.project.json & engine completeness check
    struct_errors: list[str] = []
    try:
        proj = json.loads(PROJECT_JSON.read_text(encoding="utf-8"))
        rep_storage = proj["tree"]["ReplicatedStorage"]
        starter_scripts = proj["tree"]["StarterPlayer"]["StarterPlayerScripts"]

        def verify_paths(node: dict) -> None:
            for k, v in node.items():
                if isinstance(v, dict):
                    if "$path" in v:
                        target = ROOT / v["$path"]
                        if not target.exists():
                            struct_errors.append(f"default.project.json missing $path target: {v['$path']}")
                    verify_paths(v)

        verify_paths(proj["tree"])

        if "$path" not in starter_scripts:
            struct_errors.append("StarterPlayerScripts missing $path in default.project.json")

        for engine_name, preview_name, spec_name in NEW_ENGINES:
            if engine_name not in rep_storage:
                struct_errors.append(f"ReplicatedStorage missing {engine_name} in default.project.json")
            engine_dir = ROOT / "src" / "ReplicatedStorage" / engine_name
            if not (engine_dir / "init.luau").is_file():
                struct_errors.append(f"Missing {engine_name}/init.luau")
            if not (engine_dir / "Core" / "Types.luau").is_file():
                struct_errors.append(f"Missing {engine_name}/Core/Types.luau")
            presets_dir = engine_dir / "Presets"
            if not presets_dir.is_dir() or not list(presets_dir.glob("*.luau")):
                struct_errors.append(f"Missing Presets/*.luau in {engine_name}")
            preview_file = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / preview_name
            if not preview_file.is_file():
                struct_errors.append(f"Missing {preview_name}")
            spec_file = ROOT / "docs" / spec_name
            if not spec_file.is_file():
                struct_errors.append(f"Missing docs/{spec_name}")

    except Exception as exc:  # noqa: BLE001
        struct_errors.append(f"default.project.json error: {exc}")

    if not struct_errors:
        print("[PASS] 5. default.project.json & 4-engine completeness check.")
    else:
        print("[FAIL] 5. default.project.json & 4-engine completeness check:")
        for err in struct_errors:
            print(f"  - {err}")
        failures.extend(struct_errors)

    if failures:
        print(f"\nVerification FAILED with {len(failures)} error(s).")
        return 1

    print("\nAll 5 verification checks PASSED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
