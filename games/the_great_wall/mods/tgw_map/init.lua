-- tgw_map : géométrie monde.
-- Enceinte carrée 150×150 centrée sur la maison, 4 d'épaisseur,
-- 4 tours aux coins, créneaux, échelle d'accès.

local S = core.get_translator("tgw_map")
tgw_map = {}
tgw_map.S = S

local cfg = tgw_core.config

-- ---------------------------------------------------------------------------
-- Constantes monde
-- ---------------------------------------------------------------------------

tgw_map.GROUND_Y    = 8                       -- mgflat_ground_level
tgw_map.WALL_SIZE   = cfg.wall_length         -- 150 (carré 150×150)
tgw_map.WALL_THICK  = 4
tgw_map.WALL_BASE_Y = tgw_map.GROUND_Y + 1    -- 9
tgw_map.WALL_HEIGHT = 8                       -- y[9..16]
tgw_map.WALL_TOP_Y  = tgw_map.WALL_BASE_Y + tgw_map.WALL_HEIGHT - 1  -- 16
tgw_map.CRENEL_Y    = tgw_map.WALL_TOP_Y + 1  -- 17 (alternance pleine/vide)

tgw_map.TOWER_SIZE  = 9                       -- footprint 9×9
tgw_map.TOWER_HEIGHT = 18                     -- y[9..26], toit solide à y=26
tgw_map.TOWER_TOP_Y = tgw_map.WALL_BASE_Y + tgw_map.TOWER_HEIGHT - 1  -- 26

-- Maison : derrière le mur, côté sud
tgw_map.HOUSE_POS   = { x = 0, y = tgw_map.WALL_BASE_Y, z = -20 }
tgw_map.HOUSE_SIZE  = { x = 7, y = 5, z = 7 }
tgw_map.DOOR_POS    = { x = 0, y = tgw_map.WALL_BASE_Y, z = -17 } -- face nord

-- Centre de l'enceinte = la maison
local half = math.floor(tgw_map.WALL_SIZE / 2)  -- 75
tgw_map.WALL_X_MIN = tgw_map.HOUSE_POS.x - half       -- -75
tgw_map.WALL_X_MAX = tgw_map.HOUSE_POS.x + half - 1   --  74
tgw_map.WALL_Z_MIN = tgw_map.HOUSE_POS.z - half       -- -95
tgw_map.WALL_Z_MAX = tgw_map.HOUSE_POS.z + half - 1   --  54

-- Tours aux 4 coins (5×5)
local ts = tgw_map.TOWER_SIZE
tgw_map.TOWERS = {
    sw = { x_min = tgw_map.WALL_X_MIN,            z_min = tgw_map.WALL_Z_MIN,
           x_max = tgw_map.WALL_X_MIN + ts - 1,   z_max = tgw_map.WALL_Z_MIN + ts - 1 },
    se = { x_min = tgw_map.WALL_X_MAX - ts + 1,   z_min = tgw_map.WALL_Z_MIN,
           x_max = tgw_map.WALL_X_MAX,            z_max = tgw_map.WALL_Z_MIN + ts - 1 },
    nw = { x_min = tgw_map.WALL_X_MIN,            z_min = tgw_map.WALL_Z_MAX - ts + 1,
           x_max = tgw_map.WALL_X_MIN + ts - 1,   z_max = tgw_map.WALL_Z_MAX },
    ne = { x_min = tgw_map.WALL_X_MAX - ts + 1,   z_min = tgw_map.WALL_Z_MAX - ts + 1,
           x_max = tgw_map.WALL_X_MAX,            z_max = tgw_map.WALL_Z_MAX },
}

-- Échelle d'accès au sommet : tour SW, face intérieure nord (z = z_min+ts)
tgw_map.LADDER_POS = {
    x  = tgw_map.TOWERS.sw.x_min + 2,  -- centre tour
    z  = tgw_map.TOWERS.sw.z_max + 1,  -- collée à la face intérieure
    y0 = tgw_map.WALL_BASE_Y,
    y1 = tgw_map.WALL_TOP_Y,
}

-- Zone de spawn ennemis : loin au-delà du mur nord
tgw_map.ENEMY_SPAWN_ZONE = {
    x_min = tgw_map.WALL_X_MIN + 5,
    x_max = tgw_map.WALL_X_MAX - 5,
    y     = tgw_map.WALL_BASE_Y,
    z_min = tgw_map.WALL_Z_MAX + 25,
    z_max = tgw_map.WALL_Z_MAX + 80,
}

-- Sortie pipeline ennemis (capturés → réinjectés ici, 50%)
tgw_map.PIPELINE_EXIT = {
    x = 0, y = tgw_map.WALL_BASE_Y,
    z = tgw_map.WALL_Z_MAX + 150,
}

-- Spawn joueurs (intérieur enceinte, devant la maison)
tgw_map.PLAYER_SPAWN = { x = 0, y = tgw_map.WALL_BASE_Y, z = -10 }

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

function tgw_map.get_wall_bounds()
    return {
        x_min = tgw_map.WALL_X_MIN, x_max = tgw_map.WALL_X_MAX,
        z_min = tgw_map.WALL_Z_MIN, z_max = tgw_map.WALL_Z_MAX,
        y_min = tgw_map.WALL_BASE_Y, y_max = tgw_map.WALL_TOP_Y,
        thick = tgw_map.WALL_THICK,
    }
end

function tgw_map.get_house_pos()     return vector.copy(tgw_map.HOUSE_POS) end
function tgw_map.get_door_pos()      return vector.copy(tgw_map.DOOR_POS) end
function tgw_map.get_spawn_zone()    return tgw_map.ENEMY_SPAWN_ZONE end
function tgw_map.get_player_spawn()  return vector.copy(tgw_map.PLAYER_SPAWN) end
function tgw_map.get_pipeline_exit() return vector.copy(tgw_map.PIPELINE_EXIT) end
function tgw_map.get_towers()        return tgw_map.TOWERS end
function tgw_map.get_ladder_pos()    return tgw_map.LADDER_POS end

-- Test "dans l'épaisseur du mur ou à l'extérieur"
function tgw_map.is_inside_enceinte(pos)
    return pos.x > tgw_map.WALL_X_MIN + tgw_map.WALL_THICK
       and pos.x < tgw_map.WALL_X_MAX - tgw_map.WALL_THICK + 1
       and pos.z > tgw_map.WALL_Z_MIN + tgw_map.WALL_THICK
       and pos.z < tgw_map.WALL_Z_MAX - tgw_map.WALL_THICK + 1
end

function tgw_map.is_defender_side(pos) return tgw_map.is_inside_enceinte(pos) end
function tgw_map.is_enemy_side(pos)    return not tgw_map.is_inside_enceinte(pos) end

function tgw_map.random_enemy_spawn()
    local z = tgw_map.ENEMY_SPAWN_ZONE
    return {
        x = math.random(z.x_min, z.x_max),
        y = z.y,
        z = math.random(z.z_min, z.z_max),
    }
end

core.log("action", string.format(
    "[tgw_map] loaded — enceinte X[%d..%d] Z[%d..%d] Y[%d..%d] thick=%d, 4 towers",
    tgw_map.WALL_X_MIN, tgw_map.WALL_X_MAX,
    tgw_map.WALL_Z_MIN, tgw_map.WALL_Z_MAX,
    tgw_map.WALL_BASE_Y, tgw_map.WALL_TOP_Y, tgw_map.WALL_THICK))
