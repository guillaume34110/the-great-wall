from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from .validate import validate_sprite


@dataclass
class Sprite:
    name: str
    size: int
    palette: dict[str, tuple[int, int, int, int] | None]
    grid: list[str]

    @classmethod
    def from_dict(cls, data: dict) -> "Sprite":
        v = validate_sprite(data)
        return cls(name=v["name"], size=v["size"], palette=v["palette"], grid=v["grid"])

    def to_image(self) -> Image.Image:
        img = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
        px = img.load()
        for y, row in enumerate(self.grid):
            for x, ch in enumerate(row):
                color = self.palette[ch]
                if color is None:
                    continue
                px[x, y] = color
        return img


def render_png(sprite: Sprite, out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{sprite.name}.png"
    sprite.to_image().save(path, format="PNG", optimize=True)
    return path


def load_sprites(data: dict) -> list[Sprite]:
    """Accept either single sprite or {'frames': [...]}."""
    if "frames" in data:
        frames = data["frames"]
        if not isinstance(frames, list) or not frames:
            from .validate import ValidationError
            raise ValidationError("'frames' must be a non-empty list")
        sprites = [Sprite.from_dict(f) for f in frames]
        seen: set[str] = set()
        duplicates: set[str] = set()
        for sprite in sprites:
            if sprite.name in seen:
                duplicates.add(sprite.name)
            seen.add(sprite.name)
        if duplicates:
            from .validate import ValidationError
            names = ", ".join(sorted(duplicates))
            raise ValidationError(f"duplicate frame name(s): {names}")
        return sprites
    return [Sprite.from_dict(data)]
