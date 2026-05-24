# sprite_gen

Tool autonome (hors `engine/` et `games/`) pour générer des PNG 16x16 à partir d'une grille JSON. Pas de modèle d'image, pas de cloud — l'agent LLM compose la grille, Python rend le PNG.

## Install

```bash
cd tools/sprite_gen
pip install -e .
```

Dépend uniquement de Pillow.

## Usage

```bash
# Depuis fichier
python -m sprite_gen --file leaf.json --out games/minetest_game/mods/cucumber/textures/

# Depuis stdin (workflow agent typique)
cat leaf.json | python -m sprite_gen --out games/minetest_game/mods/cucumber/textures/

# Multi-frames (crops 1..N)
python -m sprite_gen --file crops.json --out .../textures/

# Preview ASCII coloré
python -m sprite_gen --file leaf.json --preview

# Schema JSON
python -m sprite_gen --schema
```

Voir [SCHEMA.md](SCHEMA.md) pour le format.

## Hors build Docker

`tools/` est dans `.dockerignore` — l'image runtime ne contient jamais ce code. Cherry-picks Luanti upstream non impactés.

## Tests

```bash
pip install -e ".[dev]" pytest
pytest
```
