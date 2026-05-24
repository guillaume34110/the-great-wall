from __future__ import annotations

import re
from typing import Any

HEX_RE = re.compile(r"^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
NAME_PATTERN = r"^[A-Za-z0-9_]+$"
NAME_RE = re.compile(NAME_PATTERN)


class ValidationError(ValueError):
    pass


def _parse_color(value: Any) -> tuple[int, int, int, int] | None:
    if value is None:
        return None
    if not isinstance(value, str) or not HEX_RE.match(value):
        raise ValidationError(f"invalid color {value!r}, expected '#RRGGBB' or '#RRGGBBAA' or null")
    h = value[1:]
    if len(h) == 6:
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        return (r, g, b, 255)
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), int(h[6:8], 16))


def validate_sprite(data: dict) -> dict:
    """Validate one sprite dict. Returns normalized form with parsed palette."""
    if not isinstance(data, dict):
        raise ValidationError("sprite must be a JSON object")

    name = data.get("name")
    if not isinstance(name, str) or not name:
        raise ValidationError("'name' must be a non-empty string")
    if not NAME_RE.fullmatch(name):
        raise ValidationError(f"'name' must match {NAME_PATTERN}: {name!r}")

    size = data.get("size")
    if not isinstance(size, int) or size < 1 or size > 256:
        raise ValidationError("'size' must be an integer in [1, 256]")

    palette = data.get("palette")
    if not isinstance(palette, dict) or not palette:
        raise ValidationError("'palette' must be a non-empty object")
    parsed_palette: dict[str, tuple[int, int, int, int] | None] = {}
    for char, color in palette.items():
        if not isinstance(char, str) or len(char) != 1:
            raise ValidationError(f"palette key {char!r} must be a single character")
        parsed_palette[char] = _parse_color(color)

    grid = data.get("grid")
    if not isinstance(grid, list) or len(grid) != size:
        raise ValidationError(f"'grid' must be a list of {size} strings")
    for i, row in enumerate(grid):
        if not isinstance(row, str) or len(row) != size:
            raise ValidationError(f"grid[{i}] must be a string of length {size}, got {len(row) if isinstance(row, str) else type(row).__name__}")
        for j, ch in enumerate(row):
            if ch not in parsed_palette:
                raise ValidationError(f"grid[{i}][{j}]={ch!r} not in palette")

    return {"name": name, "size": size, "palette": parsed_palette, "grid": grid}


def check_seamless(grid: list[str]) -> list[str]:
    """Return a list of warnings if tile edges don't match."""
    warnings = []
    n = len(grid)
    left = "".join(row[0] for row in grid)
    right = "".join(row[-1] for row in grid)
    if left != right:
        warnings.append("tile not seamless: left edge != right edge")
    if grid[0] != grid[-1]:
        warnings.append("tile not seamless: top edge != bottom edge")
    return warnings
