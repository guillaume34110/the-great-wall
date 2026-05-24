#!/bin/sh
# Fix ownership des volumes montés par l'orchestrateur (Coolify, docker-compose).
# Tourne en root, switch vers minetest pour exec le serveur.
set -e

mkdir -p /var/lib/minetest/.minetest/worlds/world /var/lib/minetest/mods
chown -R minetest:minetest /var/lib/minetest

exec su-exec minetest:minetest /usr/local/bin/luantiserver "$@"
