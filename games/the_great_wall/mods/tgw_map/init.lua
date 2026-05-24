-- tgw_map : géométrie monde, zones, helpers.
-- Convention axes :
--   X = long du mur (est-ouest)
--   Y = vertical (sol = 8, dicté par mgflat_ground_level)
--   Z = perpendiculaire au mur. Z<0 = côté défenseur (maison). Z>0 = côté ennemi.

local S = core.get_translator("tgw_map")
tgw_map = {}
tgw_map.S = S

local cfg = tgw_core.config

-- ---------------------------------------------------------------------------
-- Constantes monde
-- ---------------------------------------------------------------------------

tgw_map.GROUND_Y    = 8                       -- mgflat_ground_level
tgw_map.WALL_Z      = 0                       -- ligne du mur
tgw_map.WALL_LENGTH = cfg.wall_length         -- 150
tgw_map.WALL_HEIGHT = cfg.wall_height         -- 6

-- Mur centré sur X=0 : X va de -75 à +74 (150 nodes)
tgw_map.WALL_X_MIN = -math.floor(tgw_map.WALL_LENGTH / 2)
tgw_map.WALL_X_MAX = tgw_map.WALL_X_MIN + tgw_map.WALL_LENGTH - 1
tgw_map.WALL_Y_MIN = tgw_map.GROUND_Y + 1     -- 9 (sur le sol)
tgw_map.WALL_Y_MAX = tgw_map.WALL_Y_MIN + tgw_map.WALL_HEIGHT - 1  -- 14

-- Maison : derrière le mur, côté défenseur
tgw_map.HOUSE_POS    = { x = 0, y = tgw_map.GROUND_Y + 1, z = -20 }
tgw_map.HOUSE_SIZE   = { x = 7, y = 5, z = 7 }   -- footprint cozy
tgw_map.DOOR_POS     = { x = 0, y = tgw_map.GROUND_Y + 1, z = -17 } -- face nord (vers le mur)

-- Zone de spawn ennemis : loin derrière le mur côté nord
tgw_map.ENEMY_SPAWN_ZONE = {
    x_min = tgw_map.WALL_X_MIN,
    x_max = tgw_map.WALL_X_MAX,
    y     = tgw_map.GROUND_Y + 1,
    z_min = 50,
    z_max = 100,
}

-- Sortie pipeline ennemis (capturés → réinjectés ici, 50%)
tgw_map.PIPELINE_EXIT = { x = 0, y = tgw_map.GROUND_Y + 1, z = 200 }

-- Spawn joueurs (défenseurs)
tgw_map.PLAYER_SPAWN = { x = 0, y = tgw_map.GROUND_Y + 1, z = -10 }

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

function tgw_map.get_wall_bounds()
    return {
        x_min = tgw_map.WALL_X_MIN, x_max = tgw_map.WALL_X_MAX,
        y_min = tgw_map.WALL_Y_MIN, y_max = tgw_map.WALL_Y_MAX,
        z     = tgw_map.WALL_Z,
    }
end

function tgw_map.get_house_pos()    return vector.copy(tgw_map.HOUSE_POS) end
function tgw_map.get_door_pos()     return vector.copy(tgw_map.DOOR_POS) end
function tgw_map.get_spawn_zone()   return tgw_map.ENEMY_SPAWN_ZONE end
function tgw_map.get_player_spawn() return vector.copy(tgw_map.PLAYER_SPAWN) end
function tgw_map.get_pipeline_exit() return vector.copy(tgw_map.PIPELINE_EXIT) end

function tgw_map.is_defender_side(pos) return pos.z <  tgw_map.WALL_Z end
function tgw_map.is_enemy_side(pos)    return pos.z >= tgw_map.WALL_Z end

-- Position aléatoire dans la zone de spawn ennemis (utilisé par tgw_waves)
function tgw_map.random_enemy_spawn()
    local z = tgw_map.ENEMY_SPAWN_ZONE
    return {
        x = math.random(z.x_min, z.x_max),
        y = z.y,
        z = math.random(z.z_min, z.z_max),
    }
end

core.log("action", "[tgw_map] loaded — wall X[" .. tgw_map.WALL_X_MIN ..
    ".." .. tgw_map.WALL_X_MAX .. "] Y[" .. tgw_map.WALL_Y_MIN ..
    ".." .. tgw_map.WALL_Y_MAX .. "] Z=" .. tgw_map.WALL_Z)
