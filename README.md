# The Great Wall

Jeu de défense Luanti. Tu joues Trump. Tu défends une maison cozy derrière un mur de 150 blocs. **200 vagues d'ennemis** essaient de traverser la frontière, casser le mur, creuser des tunnels, attaquer la porte (200 PV). Si la porte cède → game over, le serveur se reset.

Tu peux **tuer** ou **capturer** (pipeline déportation, 50% reviennent, prime plus élevée que le kill). Économie double : $ perso (tes items) + $ commun (le mur).

Survis la vague 200 → ton nom au Hall of Fame, reset.

## Stack

Fork élagué de [lumiaOpen](../lumiaOpen). Luanti server-only, Docker 3-stages, déployé via Coolify.

## Quick start

```bash
docker compose up -d --build
docker compose logs -f tgw
```

Client Luanti → `localhost:30000`. Premier joueur en `admin` → tous privs.

## Docs

- [`CLAUDE.md`](./CLAUDE.md) — architecture, conventions, spec gameplay verrouillée
- [`games/the_great_wall/`](./games/the_great_wall/) — game (mods MTG élagués + `tgw_*` custom)
- [`tools/sprite_gen/`](./tools/sprite_gen/) — générateur PNG 16×16 (obligatoire pour tout nouveau texture)

## Licence

- `engine/` : LGPL-2.1+
- `games/the_great_wall/` (fork MTG) : LGPL-2.1+ / CC-BY-SA-3.0
- `games/the_great_wall/mods/tgw_*/` : LGPL-2.1+
