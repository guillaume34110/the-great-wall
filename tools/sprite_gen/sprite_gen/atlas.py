"""Composition d'un atlas UV à partir de régions nommées.

JSON shape attendu (kind=uv_atlas) :

    {
      "name": "lumia_kobold_default",
      "rig": "mc_humanoid_64x32",          # optionnel si "canvas" fourni
      "canvas": [64, 32],                   # optionnel, override du rig
      "palette": {".": null, "S": "#7c5a3a", ...},
      "regions": {
        "head_front": ["SSSSSSSS", ...],     # une grille par région
        "torso_front": [...],
        ...
      },
      "extra_regions": {                     # optionnel, regions ad-hoc
        "weapon_decal": {"x": 50, "y": 0, "w": 6, "h": 4, "grid": [...]}
      }
    }

Régions miroir : pour le rig humanoïde, si `arm_l_*`/`leg_l_*` ne sont
pas fournis mais `arm_r_*`/`leg_r_*` le sont, on miroir-X les grilles
droites (mêmes pixels, retournés).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from .rigs import Region, get_rig
from .validate import (
    NAME_RE,
    ValidationError,
    _parse_color,  # noqa: PLC2701 — partage de la palette parser
)


_MIRROR_PAIRS = [
    ("arm_l_top",    "arm_r_top",    False),
    ("arm_l_bottom", "arm_r_bottom", False),
    ("arm_l_right",  "arm_r_left",   True),
    ("arm_l_front",  "arm_r_front",  True),
    ("arm_l_left",   "arm_r_right",  True),
    ("arm_l_back",   "arm_r_back",   True),
    ("leg_l_top",    "leg_r_top",    False),
    ("leg_l_bottom", "leg_r_bottom", False),
    ("leg_l_right",  "leg_r_left",   True),
    ("leg_l_front",  "leg_r_front",  True),
    ("leg_l_left",   "leg_r_right",  True),
    ("leg_l_back",   "leg_r_back",   True),
]


@dataclass
class Atlas:
    name: str
    canvas: tuple[int, int]
    regions: dict[str, Region]   # name -> coords
    grids: dict[str, list[str]]  # name -> grid (chars)
    palette: dict[str, tuple[int, int, int, int] | None]

    def to_image(self) -> Image.Image:
        w, h = self.canvas
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px = img.load()
        for region_name, grid in self.grids.items():
            r = self.regions[region_name]
            for y, row in enumerate(grid):
                for x, ch in enumerate(row):
                    color = self.palette[ch]
                    if color is None:
                        continue
                    px[r.x + x, r.y + y] = color
        return img


def _validate_palette(palette) -> dict[str, tuple[int, int, int, int] | None]:
    if not isinstance(palette, dict) or not palette:
        raise ValidationError("'palette' must be a non-empty object")
    out: dict[str, tuple[int, int, int, int] | None] = {}
    for char, color in palette.items():
        if not isinstance(char, str) or len(char) != 1:
            raise ValidationError(f"palette key {char!r} must be a single character")
        out[char] = _parse_color(color)
    return out


def _validate_grid(name: str, grid, w: int, h: int, palette) -> list[str]:
    if not isinstance(grid, list) or len(grid) != h:
        raise ValidationError(f"region {name!r}: grid must be a list of {h} strings, got {len(grid) if isinstance(grid, list) else type(grid).__name__}")
    out = []
    for i, row in enumerate(grid):
        if not isinstance(row, str) or len(row) != w:
            raise ValidationError(f"region {name!r}: grid[{i}] must be a string of length {w}")
        for j, ch in enumerate(row):
            if ch not in palette:
                raise ValidationError(f"region {name!r}: grid[{i}][{j}]={ch!r} not in palette")
        out.append(row)
    return out


def _mirror_x(grid: list[str]) -> list[str]:
    return [row[::-1] for row in grid]


def load_atlas(data: dict) -> Atlas:
    if not isinstance(data, dict):
        raise ValidationError("uv_atlas payload must be a JSON object")

    name = data.get("name")
    if not isinstance(name, str) or not NAME_RE.fullmatch(name):
        raise ValidationError("'name' must be a string matching ^[A-Za-z0-9_]+$")

    rig_name = data.get("rig")
    rig = get_rig(rig_name) if rig_name else None
    if rig_name and not rig:
        raise ValidationError(f"unknown rig {rig_name!r}")

    canvas = data.get("canvas")
    if canvas is None and rig is not None:
        canvas = rig.canvas
    if (not isinstance(canvas, (list, tuple)) or len(canvas) != 2
            or not all(isinstance(v, int) and 1 <= v <= 1024 for v in canvas)):
        raise ValidationError("'canvas' must be [w, h] of ints in [1,1024] (or set 'rig')")
    canvas = (int(canvas[0]), int(canvas[1]))

    palette = _validate_palette(data.get("palette"))

    # regions = name -> grid (uses rig coords)
    user_regions = data.get("regions") or {}
    if not isinstance(user_regions, dict):
        raise ValidationError("'regions' must be an object")

    # extra_regions = ad-hoc {name: {x,y,w,h,grid}}
    extra = data.get("extra_regions") or {}
    if not isinstance(extra, dict):
        raise ValidationError("'extra_regions' must be an object")

    coords: dict[str, Region] = {}
    grids: dict[str, list[str]] = {}

    if rig is not None:
        for r_name, grid in user_regions.items():
            if r_name not in rig.regions:
                raise ValidationError(f"region {r_name!r} not in rig {rig.name!r}")
            r = rig.regions[r_name]
            coords[r_name] = r
            grids[r_name] = _validate_grid(r_name, grid, r.w, r.h, palette)

        # auto-miroir gauche depuis droite si pertinent
        for left, right, flip in _MIRROR_PAIRS:
            if left in rig.regions and left not in grids and right in grids:
                lr = rig.regions[left]
                src = grids[right]
                coords[left] = lr
                grids[left] = _mirror_x(src) if flip else list(src)
    else:
        # pas de rig : chaque région doit fournir x/y/w/h
        for r_name, blob in user_regions.items():
            if not isinstance(blob, dict):
                raise ValidationError(f"region {r_name!r}: expected object with x,y,w,h,grid (no rig set)")
            try:
                x, y, w, h = blob["x"], blob["y"], blob["w"], blob["h"]
            except KeyError as e:
                raise ValidationError(f"region {r_name!r}: missing key {e.args[0]!r}") from e
            coords[r_name] = Region(int(x), int(y), int(w), int(h))
            grids[r_name] = _validate_grid(r_name, blob.get("grid"), int(w), int(h), palette)

    for r_name, blob in extra.items():
        if not isinstance(blob, dict):
            raise ValidationError(f"extra_regions[{r_name!r}]: expected object")
        try:
            x, y, w, h = blob["x"], blob["y"], blob["w"], blob["h"]
        except KeyError as e:
            raise ValidationError(f"extra_regions[{r_name!r}]: missing key {e.args[0]!r}") from e
        coords[r_name] = Region(int(x), int(y), int(w), int(h))
        grids[r_name] = _validate_grid(r_name, blob.get("grid"), int(w), int(h), palette)

    # bounds check
    cw, ch = canvas
    for r_name, r in coords.items():
        if r.x < 0 or r.y < 0 or r.x + r.w > cw or r.y + r.h > ch:
            raise ValidationError(f"region {r_name!r} {r} out of canvas {canvas}")

    return Atlas(name=name, canvas=canvas, regions=coords, grids=grids, palette=palette)


def render_atlas_png(atlas: Atlas, out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{atlas.name}.png"
    atlas.to_image().save(path, format="PNG", optimize=True)
    return path
