import json
from pathlib import Path

import pytest
from PIL import Image

from sprite_gen.__main__ import SCHEMA, main
from sprite_gen.grid import Sprite, load_sprites, render_png
from sprite_gen.validate import NAME_PATTERN, ValidationError, check_seamless


SAMPLE = {
    "name": "test_leaf",
    "size": 4,
    "palette": {".": None, "G": "#3a7d2c", "g": "#5ba83d"},
    "grid": [".gG.", "gGGg", "gGGg", ".gG."],
}


def test_render_png(tmp_path: Path):
    sprite = Sprite.from_dict(SAMPLE)
    path = render_png(sprite, tmp_path)
    assert path.exists()
    img = Image.open(path)
    assert img.size == (4, 4)
    assert img.mode == "RGBA"
    assert img.getpixel((0, 0)) == (0, 0, 0, 0)
    assert img.getpixel((1, 0))[:3] == (0x5b, 0xa8, 0x3d)
    assert img.getpixel((2, 0))[:3] == (0x3a, 0x7d, 0x2c)


def test_validate_size_mismatch():
    bad = dict(SAMPLE, size=8)
    with pytest.raises(ValidationError):
        Sprite.from_dict(bad)


def test_validate_unknown_char():
    bad = dict(SAMPLE, grid=["XXXX", "gGGg", "gGGg", ".gG."])
    with pytest.raises(ValidationError):
        Sprite.from_dict(bad)


def test_validate_bad_color():
    bad = dict(SAMPLE, palette={".": None, "G": "green", "g": "#5ba83d"})
    with pytest.raises(ValidationError):
        Sprite.from_dict(bad)


def test_name_no_slash():
    bad = dict(SAMPLE, name="foo/bar")
    with pytest.raises(ValidationError):
        Sprite.from_dict(bad)


def test_name_matches_schema_contract():
    bad = dict(SAMPLE, name="foo-bar")
    with pytest.raises(ValidationError):
        Sprite.from_dict(bad)
    assert SCHEMA["$defs"]["sprite"]["properties"]["name"]["pattern"] == NAME_PATTERN


def test_alpha_color():
    data = dict(SAMPLE, palette={".": None, "G": "#3a7d2c80", "g": "#5ba83d"})
    s = Sprite.from_dict(data)
    assert s.palette["G"] == (0x3a, 0x7d, 0x2c, 0x80)


def test_frames(tmp_path: Path):
    bundle = {"frames": [dict(SAMPLE, name="f_1"), dict(SAMPLE, name="f_2")]}
    sprites = load_sprites(bundle)
    assert [s.name for s in sprites] == ["f_1", "f_2"]
    for s in sprites:
        render_png(s, tmp_path)
    assert (tmp_path / "f_1.png").exists()
    assert (tmp_path / "f_2.png").exists()


def test_duplicate_frame_names_rejected():
    bundle = {"frames": [dict(SAMPLE, name="same"), dict(SAMPLE, name="same")]}
    with pytest.raises(ValidationError, match="duplicate frame name"):
        load_sprites(bundle)


def test_seamless_warns():
    grid = ["GGGG", "gggg", "gggg", "gggg"]
    warns = check_seamless(grid)
    assert any("top" in w or "bottom" in w for w in warns)


def test_cli_schema(capsys):
    rc = main(["--schema"])
    assert rc == 0
    out = capsys.readouterr().out
    parsed = json.loads(out)
    assert "$defs" in parsed


def test_cli_missing_input_file_reports_error(tmp_path: Path, capsys):
    rc = main(["--file", str(tmp_path / "missing.json")])
    assert rc == 2
    err = capsys.readouterr().err
    assert "cannot read" in err
    assert "missing.json" in err


def test_cli_output_write_error_reports_cleanly(tmp_path: Path, capsys):
    payload = tmp_path / "sprite.json"
    payload.write_text(json.dumps(SAMPLE))
    blocking = tmp_path / "not_a_dir"
    blocking.write_text("x")

    rc = main(["--file", str(payload), "--out", str(blocking)])
    assert rc == 2
    err = capsys.readouterr().err
    assert "cannot write" in err
    assert "test_leaf.png" in err
