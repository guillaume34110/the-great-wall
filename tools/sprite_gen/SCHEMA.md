# Sprite JSON schema

Minimal grid-to-PNG format for agents.

## Single sprite

```json
{
  "name": "cucumber_leaf",
  "size": 16,
  "palette": {
    "G": "#3a7d2c",
    "g": "#5ba83d",
    "d": "#1f4a17",
    ".": null
  },
  "grid": [
    "................",
    ".....ggGgg......",
    "....gGGGGGg.....",
    "...gGGdGGGGg....",
    "...gGdGGGGGg....",
    "...gGGGGGdGg....",
    "....gGGdGGg.....",
    ".....ggGgg......",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................"
  ]
}
```

## Rules

- `size`: integer, must equal `len(grid)` AND `len(grid[i])`. Typical 16, 32, 64.
- `palette`: dict char → `"#RRGGBB"`, `"#RRGGBBAA"`, or `null` (transparent).
- `grid`: list of strings, each char must exist in palette.
- `name`: output filename without `.png`, matching `^[A-Za-z0-9_]+$`. Final file = `<out>/<name>.png`.

## Multi-frame (crops, animations)

Wrap an array of sprites:

```json
{
  "frames": [
    { "name": "cucumber_cucumber_1", "size": 16, "palette": {...}, "grid": [...] },
    { "name": "cucumber_cucumber_2", "size": 16, "palette": {...}, "grid": [...] }
  ]
}
```

Each frame written as separate PNG. Frame `name` values must be unique within the bundle.

## Tips for agents

- Prefer 16x16 (MTG standard).
- Use `null` (alpha) for items, full opaque grid for tiles.
- For tiles: ensure left/right and top/bottom edges match (seamless). The CLI warns if not.
- Keep palette ≤ 16 colors for MTG style coherence.
- Reuse presets: see `tools/sprite_gen/sprite_gen/presets.py` (`mtg.foliage`, `mtg.wood`, ...).
- Get this schema at runtime: `python -m sprite_gen --schema`.

## UV atlas (`--kind uv_atlas`)

Compose un atlas multi-régions sur un canvas — pour texturer un B3D rigué
(mobs_redo humanoïdes type goblins/skeletons). L'animation vient du modèle,
pas de l'image : ce mode produit juste une "peau" qui s'applique au rig.

```json
{
  "name": "lumia_kobold_default",
  "rig": "mc_humanoid_64x32",
  "palette": {".": null, "S": "#7c5a3a", "h": "#b58a5c", "T": "#3a2410"},
  "regions": {
    "head_front":  ["SShhhhSS", "ShhhhhhS", "hhhhhhhh", "hhhhhhhh",
                    "hhhTThhh", "hhhTThhh", "ShhhhhhS", "SShhhhSS"],
    "torso_front": ["...12 lignes de 8..."],
    "arm_r_front": ["...12 lignes de 4..."],
    "leg_r_front": ["...12 lignes de 4..."]
  }
}
```

- `rig` : nom du preset (lister via `python -m sprite_gen --list-rigs`).
  Pose la taille canvas et la grille de coordonnées de chaque région.
- `regions[name]` : grille de chars matchant la taille de la région.
  Faces non fournies = transparentes.
- `extra_regions[name] = {x, y, w, h, grid}` : régions hors-rig (décal,
  arme cousue, blason custom...).
- Sans `rig` : fournir `canvas: [w, h]` + chaque entrée
  `regions[name] = {x, y, w, h, grid}` (mode freeform).
- Auto-mirror : pour les rigs avec bras/jambes gauches en UV séparés,
  fournir uniquement `arm_r_*` / `leg_r_*` suffit — les faces gauches
  sont mirrorées sur X automatiquement.

Rig fourni :
- `mc_humanoid_64x32` — layout Minecraft legacy 64×32, compatible avec la
  plupart des humanoïdes mobs_redo (goblins, mobs_skeletons, mobs_animal:npc).
  Régions : `head_{top,bottom,right,front,left,back}`,
  `torso_{top,bottom,right,front,left,back}`,
  `arm_r_{top,bottom,right,front,left,back}`,
  `leg_r_{top,bottom,right,front,left,back}`.
