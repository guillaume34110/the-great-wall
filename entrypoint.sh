#!/bin/sh
# Fix ownership des volumes montés par l'orchestrateur (Coolify, docker-compose).
# Tourne en root, switch vers minetest pour exec le serveur.
set -e

mkdir -p /var/lib/minetest/.minetest/worlds/world /var/lib/minetest/mods

# WIPE=1 : reset complet du monde (HoF préservé : stocké hors worldpath)
if [ "${WIPE:-0}" = "1" ]; then
    echo "[entrypoint] WIPE=1 → suppression du contenu du monde"
    find /var/lib/minetest/.minetest/worlds/world -mindepth 1 -delete 2>/dev/null || true
fi

chown -R minetest:minetest /var/lib/minetest

exec su-exec minetest:minetest /usr/local/bin/luantiserver "$@"
