from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .atlas import load_atlas, render_atlas_png
from .grid import load_sprites, render_png
from .rigs import RIGS
from .validate import NAME_PATTERN, ValidationError, check_seamless


SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "title": "Lumia sprite grid",
    "oneOf": [
        {"$ref": "#/$defs/sprite"},
        {
            "type": "object",
            "required": ["frames"],
            "properties": {
                "frames": {"type": "array", "minItems": 1, "items": {"$ref": "#/$defs/sprite"}}
            },
        },
    ],
    "$defs": {
        "sprite": {
            "type": "object",
            "required": ["name", "size", "palette", "grid"],
            "properties": {
                "name": {"type": "string", "pattern": NAME_PATTERN},
                "size": {"type": "integer", "minimum": 1, "maximum": 256},
                "palette": {
                    "type": "object",
                    "minProperties": 1,
                    "additionalProperties": {
                        "anyOf": [
                            {"type": "string", "pattern": "^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"},
                            {"type": "null"},
                        ]
                    },
                },
                "grid": {"type": "array", "items": {"type": "string"}},
            },
        }
    },
}


ANSI_RESET = "\x1b[0m"


def _ansi_bg(rgba):
    if rgba is None:
        return "\x1b[48;2;30;30;30m"
    r, g, b, _ = rgba
    return f"\x1b[48;2;{r};{g};{b}m"


def preview(sprite) -> str:
    lines = []
    for row in sprite.grid:
        chunks = []
        for ch in row:
            chunks.append(f"{_ansi_bg(sprite.palette[ch])}  {ANSI_RESET}")
        lines.append("".join(chunks))
    return "\n".join(lines)


def _read_input(args) -> dict:
    if args.file:
        path = Path(args.file)
        try:
            return json.loads(path.read_text())
        except OSError as e:
            raise OSError(f"cannot read {path}: {e.strerror or e}") from e
    return json.loads(sys.stdin.read())


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="sprite_gen", description="JSON grid -> PNG sprite for Lumia/Luanti mods.")
    p.add_argument("--file", help="JSON file (default: stdin)")
    p.add_argument("--out", default=".", help="Output directory")
    p.add_argument("--kind", choices=["item", "tile", "crop", "wield", "mob", "uv_atlas"], default="item",
                   help="Sprite kind (drives validations / composition)")
    p.add_argument("--preview", action="store_true", help="ASCII colored preview, no PNG written")
    p.add_argument("--schema", action="store_true", help="Print JSON schema and exit")
    p.add_argument("--list-rigs", action="store_true", help="List available UV atlas rigs and exit")
    args = p.parse_args(argv)

    if args.schema:
        json.dump(SCHEMA, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 0

    if args.list_rigs:
        for name, rig in RIGS.items():
            print(f"{name}  canvas={rig.canvas[0]}x{rig.canvas[1]}  regions={len(rig.regions)}")
            for r_name, r in rig.regions.items():
                print(f"  {r_name:14s} x={r.x:2d} y={r.y:2d} w={r.w:2d} h={r.h:2d}")
        return 0

    try:
        data = _read_input(args)
        if args.kind == "uv_atlas":
            atlas = load_atlas(data)
        else:
            sprites = load_sprites(data)
    except (json.JSONDecodeError, ValidationError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    except OSError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    out = Path(args.out)

    if args.kind == "uv_atlas":
        if args.preview:
            print(f"# {atlas.name} canvas={atlas.canvas[0]}x{atlas.canvas[1]} "
                  f"regions={len(atlas.grids)}")
            return 0
        try:
            path = render_atlas_png(atlas, out)
        except OSError as e:
            target = out / f"{atlas.name}.png"
            print(f"error: cannot write {target}: {e.strerror or e}", file=sys.stderr)
            return 2
        print(f"wrote {path}")
        return 0

    if args.preview:
        for s in sprites:
            print(f"# {s.name} ({s.size}x{s.size})")
            print(preview(s))
        return 0

    for s in sprites:
        if args.kind == "tile":
            for w in check_seamless(s.grid):
                print(f"warning [{s.name}]: {w}", file=sys.stderr)
        try:
            path = render_png(s, out)
        except OSError as e:
            target = out / f"{s.name}.png"
            print(f"error: cannot write {target}: {e.strerror or e}", file=sys.stderr)
            return 2
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
