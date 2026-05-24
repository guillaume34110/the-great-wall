"""Presets de rigs UV pour mobs animés (B3D/X mobs_redo-style).

Un `Rig` décrit le canvas (w, h) + un dict de régions nommées
`{region_name: (x, y, w, h)}`. L'utilisateur fournit une grille de chars
par région ; `atlas.compose_atlas` les pose aux bonnes coordonnées et
sort un PNG du canvas complet.

Les rigs ici sont indépendants d'un modèle précis : ils décrivent une
convention d'unwrap. Tout B3D/X dont l'UV suit cette convention peut
réutiliser le même rig.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Region:
    x: int
    y: int
    w: int
    h: int


@dataclass(frozen=True)
class Rig:
    name: str
    canvas: tuple[int, int]
    regions: dict[str, Region]


def _r(x, y, w, h):
    return Region(x, y, w, h)


# Layout Minecraft "legacy" 64×32 — standard de facto pour humanoïdes
# mobs_redo (goblins, skeletons, npc...). Bras/jambes gauches sont des
# miroirs des droits côté géométrie ; ici on expose les deux noms et la
# composition copie automatiquement la droite vers la gauche si seule la
# droite est fournie (cf. atlas.compose_atlas).
MC_HUMANOID_64x32 = Rig(
    name="mc_humanoid_64x32",
    canvas=(64, 32),
    regions={
        # ---- tête (cube 8x8x8) ----
        "head_top":     _r(8,  0, 8, 8),
        "head_bottom":  _r(16, 0, 8, 8),
        "head_right":   _r(0,  8, 8, 8),
        "head_front":   _r(8,  8, 8, 8),
        "head_left":    _r(16, 8, 8, 8),
        "head_back":    _r(24, 8, 8, 8),
        # ---- torse (8x12x4) ----
        "torso_top":    _r(20, 16, 8, 4),
        "torso_bottom": _r(28, 16, 8, 4),
        "torso_right":  _r(16, 20, 4, 12),
        "torso_front":  _r(20, 20, 8, 12),
        "torso_left":   _r(28, 20, 4, 12),
        "torso_back":   _r(32, 20, 8, 12),
        # ---- bras droit (4x12x4) ----
        "arm_r_top":    _r(44, 16, 4, 4),
        "arm_r_bottom": _r(48, 16, 4, 4),
        "arm_r_right":  _r(40, 20, 4, 12),
        "arm_r_front":  _r(44, 20, 4, 12),
        "arm_r_left":   _r(48, 20, 4, 12),
        "arm_r_back":   _r(52, 20, 4, 12),
        # ---- jambe droite (4x12x4) ----
        "leg_r_top":    _r(4,  16, 4, 4),
        "leg_r_bottom": _r(8,  16, 4, 4),
        "leg_r_right":  _r(0,  20, 4, 12),
        "leg_r_front":  _r(4,  20, 4, 12),
        "leg_r_left":   _r(8,  20, 4, 12),
        "leg_r_back":   _r(12, 20, 4, 12),
    },
)


RIGS: dict[str, Rig] = {
    MC_HUMANOID_64x32.name: MC_HUMANOID_64x32,
}


def get_rig(name: str) -> Rig | None:
    return RIGS.get(name)
