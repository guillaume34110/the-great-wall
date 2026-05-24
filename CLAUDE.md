# CLAUDE.md — The Great Wall

Guidance pour Claude Code sur ce repo.

## Projet

**The Great Wall** : jeu de défense Luanti. Joueurs incarnent Trump, défendent une maison cozy derrière un mur de 150 blocs contre 200 vagues d'ennemis (« Mexicains ») qui tentent de traverser. Tuer ou capturer (éthique différenciée, récompenses différentes). Fork élagué de [lumiaOpen](../lumiaOpen) — mêmes infrastructures, gameplay totalement différent.

## Spec gameplay verrouillée

| Élément | Valeur |
|---|---|
| Mur | 150 × 6 blocs, fixe quel que soit nb joueurs |
| Scaling joueurs | Multiplie taux de spawn ennemis, **pas** la longueur du mur |
| Maison | 1 commune. **Porte = 200 PV** = unique critère defeat |
| Run | 200 vagues, paliers progressifs, lancée par bouton dans maison |
| Reset | Auto sur defeat OU victory → wipe world, HoF préservé |
| Respawn | Cooldown 10s + nu + concombre starter |
| Captures | Pipeline → sortie autre bout map → 50% reviennent |
| Économie | $ perso (items) + $ commun (mur, défenses globales) |
| Récompense | Capture (entrée tuyau) > Kill |
| Nuit | Densité ×1.5, types durs +30% |
| Friendly fire | OFF |

## Architecture

Trois surfaces, comme lumiaOpen :

- **Engine (C++)** → `engine/`. Vendored, **ne pas toucher** sauf demande explicite. Rebuild ~10-15 min.
- **Game (Lua)** → `games/the_great_wall/mods/`. Fork élagué de minetest_game + mods `tgw_*` custom.
- **User mods** → `data/mods/` (runtime, pas dans l'image).

Build Docker 3 stages identique à lumiaOpen (Alpine, LuaJIT, prometheus-cpp, libspatialindex). Conteneur `the-great-wall`, port UDP 30000.

## Mods game inclus

**Vendored upstream (gardés)** : `default`, `player_api`, `fire`, `tnt`, `stairs`, `walls`, `doors`, `dye`, `map`, `mobs_redo` (framework), `lumia_chargen` (gen ennemis ubiquitaires), `lumia_music`, `xcompat`, `sfinv`, `spawn`, `sethome`, `futil`, `fmod`, `game_commands`, `preprod_setup`.

**Custom `tgw_*`** (15 mods, voir squelettes) :

| Mod | Rôle |
|---|---|
| `tgw_core` | State machine (LOBBY/RUN/DEFEAT/VICTORY) + event bus + config partagée |
| `tgw_economy` | Dual-wallet : perso (items) + commun (mur) |
| `tgw_wall` | Génération mur 150×6, HP par node, réparation via $ commun |
| `tgw_house` | Maison cozy, bouton start, porte 200 PV (defeat trigger) |
| `tgw_map` | Mapgen flat, frontière, zone spawn ennemis |
| `tgw_invader` | Entité ennemi : path, casse mur, tunnels, 3 types (runner/tank/digger) |
| `tgw_waves` | 200 vagues, scaling joueurs × wave_idx × night |
| `tgw_combat` | Armes létales (kill reward = base) |
| `tgw_capture` | Armes non-létales → pipeline |
| `tgw_pipeline` | Tuyau déportation, sortie bout map, RNG 50% retour |
| `tgw_shop` | Formspec achat, distingue wallets |
| `tgw_trump_skin` | Skin Trump + loadout default |
| `tgw_hud` | Affichage vague/$/mur HP/porte HP/jour-nuit |
| `tgw_hof` | Hall of Fame persistant (survit reset world) |
| `tgw_reset` | Reset auto serveur (wipe world, regen, retour lobby) |

## Conventions Lua

- Namespace `core.*` (préférer à `minetest.*` legacy).
- Item IDs : `tgw_<modname>:<thing>`.
- Communication inter-mods : via event bus `tgw_core.on(event, fn)` / `tgw_core.emit(event, payload)`. Éviter dépendances dures inutiles.
- Pas de `farming` ni de `creative` : c'est un jeu **pas un sandbox**. Joueurs n'ont pas `place` libre — réparation/défense via shop.

### Génération sprites (obligatoire)

Tout nouveau node/item/tool nécessite un PNG 16×16. **Ne jamais créer `.png` à la main.** Utiliser `tools/sprite_gen/` :

```bash
PYTHONPATH=tools/sprite_gen python3 -m sprite_gen \
  --out games/the_great_wall/mods/<mod>/textures/ \
  --kind item|tile|crop|wield|mob \
  --file <grid>.json
```

Voir `tools/sprite_gen/SCHEMA.md` et `tools/sprite_gen/sprite_gen/presets.py`.

## Commandes

```bash
docker compose up -d --build      # build + run (10-15 min première fois)
docker compose logs -f tgw        # logs
docker compose restart tgw        # restart après edit Lua (bind-mount ci-dessous)
docker compose down               # stop
WIPE=1 docker compose up -d       # reset world au démarrage (HoF préservé)
```

Connect : Luanti client → `localhost:30000`.

### Itération rapide Lua (bind-mount)

`docker-compose.override.yml` :
```yaml
services:
  tgw:
    volumes:
      - ./games/the_great_wall:/usr/local/share/luanti/games/the_great_wall:ro
```
Puis `docker compose restart tgw` après chaque edit.

## Mac dev

Bind-mount `~/Documents/...` bloqué par Docker Desktop par défaut. Soit autoriser dans Settings → Resources → File Sharing, soit `cp docker-compose.override.yml.example docker-compose.override.yml` (volume nommé + `/tmp` pour la conf).

## Coolify deploy

Identique lumiaOpen : UDP/30000 ouvert host, `./data` persistent storage, DNS A `greatwall.progsoft.eu`.

## Note langue

Code/commentaires en **français** (suivre lumiaOpen). Item IDs et clés techniques en anglais.

## Référence

- Luanti API : https://api.luanti.org/
- MTG game_api : `games/the_great_wall/game_api.txt`
- Engine Lua API : `engine/doc/lua_api.md`
- Sprite gen : `tools/sprite_gen/README.md`
