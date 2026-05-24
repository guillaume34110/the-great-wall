import json
from pathlib import Path

import pytest
from PIL import Image

from sprite_gen.__main__ import main
from sprite_gen.atlas import load_atlas, render_atlas_png
from sprite_gen.validate import ValidationError


def _solid_grid(ch: str, w: int, h: int) -> list[str]:
    return [ch * w] * h


def _full_humanoid(name: str = "test_atlas", *, head_ch: str = "H",
                   torso_ch: str = "T", arm_ch: str = "A", leg_ch: str = "L") -> dict:
    palette = {
        ".": None,
        head_ch: "#cc8855",
        torso_ch: "#226633",
        arm_ch: "#557799",
        leg_ch: "#332211",
    }
    sizes = {
        "head": (8, 8),
        "torso_top": (8, 4), "torso_bottom": (8, 4),
        "torso_side": (4, 12), "torso_face": (8, 12),
        "limb_cap": (4, 4), "limb_face": (4, 12),
    }
    regions: dict[str, list[str]] = {}
    for face in ("top", "bottom", "right", "front", "left", "back"):
        regions[f"head_{face}"] = _solid_grid(head_ch, *sizes["head"])
    regions["torso_top"]    = _solid_grid(torso_ch, *sizes["torso_top"])
    regions["torso_bottom"] = _solid_grid(torso_ch, *sizes["torso_bottom"])
    regions["torso_right"]  = _solid_grid(torso_ch, *sizes["torso_side"])
    regions["torso_left"]   = _solid_grid(torso_ch, *sizes["torso_side"])
    regions["torso_front"]  = _solid_grid(torso_ch, *sizes["torso_face"])
    regions["torso_back"]   = _solid_grid(torso_ch, *sizes["torso_face"])
    for face in ("top", "bottom"):
        regions[f"arm_r_{face}"] = _solid_grid(arm_ch, *sizes["limb_cap"])
        regions[f"leg_r_{face}"] = _solid_grid(leg_ch, *sizes["limb_cap"])
    for face in ("right", "front", "left", "back"):
        regions[f"arm_r_{face}"] = _solid_grid(arm_ch, *sizes["limb_face"])
        regions[f"leg_r_{face}"] = _solid_grid(leg_ch, *sizes["limb_face"])
    return {"name": name, "rig": "mc_humanoid_64x32", "palette": palette, "regions": regions}


def test_atlas_renders_canvas(tmp_path: Path):
    atlas = load_atlas(_full_humanoid())
    path = render_atlas_png(atlas, tmp_path)
    img = Image.open(path).convert("RGBA")
    assert img.size == (64, 32)
    # head_front pixels (8..15, 8..15) → head color
    assert img.getpixel((8, 8))[:3] == (0xcc, 0x88, 0x55)
    # torso_front (20..27, 20..31) → torso color
    assert img.getpixel((20, 20))[:3] == (0x22, 0x66, 0x33)
    # arm_r_front (44..47, 20..31) → arm color
    assert img.getpixel((44, 20))[:3] == (0x55, 0x77, 0x99)
    # leg_r_front (4..7, 20..31) → leg color
    assert img.getpixel((4, 20))[:3] == (0x33, 0x22, 0x11)


def test_atlas_unknown_rig():
    bad = _full_humanoid()
    bad["rig"] = "no_such_rig"
    with pytest.raises(ValidationError, match="unknown rig"):
        load_atlas(bad)


def test_atlas_unknown_region():
    bad = _full_humanoid()
    bad["regions"]["wing_left"] = _solid_grid("H", 4, 4)
    with pytest.raises(ValidationError, match="not in rig"):
        load_atlas(bad)


def test_atlas_grid_size_mismatch():
    bad = _full_humanoid()
    bad["regions"]["head_front"] = ["HHHH"] * 8  # width 4 instead of 8
    with pytest.raises(ValidationError, match="head_front"):
        load_atlas(bad)


def test_atlas_no_rig_requires_coords():
    payload = {
        "name": "freeform",
        "canvas": [16, 16],
        "palette": {".": None, "X": "#ff00ff"},
        "regions": {
            "blob": {"x": 2, "y": 2, "w": 4, "h": 4, "grid": _solid_grid("X", 4, 4)},
        },
    }
    atlas = load_atlas(payload)
    img = atlas.to_image()
    assert img.getpixel((2, 2))[:3] == (0xff, 0x00, 0xff)
    assert img.getpixel((0, 0))[3] == 0


def test_atlas_extra_regions_outside_canvas_rejected():
    bad = _full_humanoid()
    bad["extra_regions"] = {
        "out": {"x": 60, "y": 28, "w": 8, "h": 8, "grid": _solid_grid("H", 8, 8)},
    }
    with pytest.raises(ValidationError, match="out of canvas"):
        load_atlas(bad)


def test_cli_uv_atlas(tmp_path: Path, capsys):
    payload_file = tmp_path / "atlas.json"
    payload_file.write_text(json.dumps(_full_humanoid("cli_atlas")))
    rc = main(["--kind", "uv_atlas", "--file", str(payload_file), "--out", str(tmp_path)])
    assert rc == 0
    assert (tmp_path / "cli_atlas.png").exists()


def test_cli_list_rigs(capsys):
    rc = main(["--list-rigs"])
    assert rc == 0
    out = capsys.readouterr().out
    assert "mc_humanoid_64x32" in out
    assert "head_front" in out
