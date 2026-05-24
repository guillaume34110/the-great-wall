-- Détection contexte musical avec hystérésis pour éviter le flapping.
-- État zone/biome maintenu côté triggers : la sortie d'une zone exige
-- de franchir un rayon "exit" plus large que l'entrée.

local Trig = {}
lumia_music.triggers = Trig

local function settings_float(k, default)
    local v = minetest.settings:get(k)
    if v then return tonumber(v) or default end
    return default
end

-- Hystérésis : on entre à ENTER, on sort seulement après EXIT (> ENTER).
local VILLAGE_ENTER = settings_float("lumia.music_village_enter", 50)
local VILLAGE_EXIT  = settings_float("lumia.music_village_exit",  90)
local HAVEN_EXTRA_ENTER = 40
local HAVEN_EXTRA_EXIT  = 80

local UNDERGROUND_ENTER_Y = -16
local UNDERGROUND_EXIT_Y  = -8

local FACTION_TRACK = {
    undead_sun = "desert",
    primordial = "coast",
    construct  = "mountain",
    geobio     = "forest",
}

-- État par joueur
local zone_state = {}  -- name -> {in_village, in_haven, in_underground, last_biome_slug, biome_streak}

local function st(player_name)
    local s = zone_state[player_name]
    if not s then
        s = {in_village = nil, in_haven = false, in_underground = false,
             last_biome_slug = nil, biome_streak = 0}
        zone_state[player_name] = s
    end
    return s
end

function Trig.reset_player(name) zone_state[name] = nil end

local function dist2(a, b)
    local dx = a.x - b.x; local dz = a.z - b.z
    return dx * dx + dz * dz
end

local function haven_check(pos, s)
    if not (lumia_camps and lumia_camps.haven and lumia_camps.haven.center) then
        return false
    end
    local c = lumia_camps.haven.center
    local base = lumia_camps.haven.island_radius or 100
    local r = base + (s.in_haven and HAVEN_EXTRA_EXIT or HAVEN_EXTRA_ENTER)
    local in_zone = dist2(pos, c) < r * r
    s.in_haven = in_zone
    return in_zone
end

local function village_check(pos, s)
    local sites = lumia_world and lumia_world.village_sites
    if not sites then s.in_village = nil; return nil end
    local r = s.in_village and VILLAGE_EXIT or VILLAGE_ENTER
    local r2 = r * r
    -- Si on était dans un village, on vérifie d'abord celui-là (sticky)
    if s.in_village then
        local sp = s.in_village.route_anchor or s.in_village.pos or s.in_village.nominal_pos
        if sp and dist2(pos, sp) < r2 then return s.in_village end
        s.in_village = nil
    end
    local r2_enter = VILLAGE_ENTER * VILLAGE_ENTER
    local best, bestd
    for _, site in ipairs(sites) do
        local sp = site.route_anchor or site.pos or site.nominal_pos
        if sp then
            local d = dist2(pos, sp)
            if d < r2_enter and (not bestd or d < bestd) then
                best, bestd = site, d
            end
        end
    end
    s.in_village = best
    return best
end

local function underground_check(pos, s)
    local thresh = s.in_underground and UNDERGROUND_EXIT_Y or UNDERGROUND_ENTER_Y
    s.in_underground = pos.y < thresh
    return s.in_underground
end

local function biome_to_slug(name)
    if not name then return "overworld_day" end
    name = name:lower()
    if name:find("desert") or name:find("savanna") then return "desert" end
    if name:find("beach") or name:find("ocean") or name:find("coast") then return "coast" end
    if name:find("forest") or name:find("jungle") or name:find("taiga") or name:find("grassland") then return "forest" end
    if name:find("mountain") or name:find("tundra") or name:find("snow") or name:find("stone") then return "mountain" end
    return "overworld_day"
end

local function is_night()
    local t = minetest.get_timeofday() or 0.5
    return t < 0.20 or t > 0.80
end

-- Biome avec lissage : on ne valide un changement qu'après N ticks consécutifs.
local BIOME_STREAK_REQUIRED = 2
local function smoothed_biome(pos, s)
    local biome
    local bd = minetest.get_biome_data(pos)
    if bd and bd.biome then biome = minetest.get_biome_name(bd.biome) end
    local raw = biome_to_slug(biome)
    if raw == s.last_biome_slug then
        s.biome_streak = 0
        return raw
    end
    s.biome_streak = (s.biome_streak or 0) + 1
    if s.biome_streak >= BIOME_STREAK_REQUIRED then
        s.last_biome_slug = raw
        s.biome_streak = 0
        return raw
    end
    return s.last_biome_slug or raw
end

function Trig.pick_ambient(player)
    local pos = player:get_pos()
    local name = player:get_player_name()
    local s = st(name)

    if underground_check(pos, s) then
        return "dungeon"
    end
    if haven_check(pos, s) then
        return "haven"
    end
    local v = village_check(pos, s)
    if v then
        local fid = v.faction and v.faction.id
        if fid and FACTION_TRACK[fid] then return FACTION_TRACK[fid] end
        return "village"
    end
    local slug = smoothed_biome(pos, s)
    if slug == "overworld_day" and is_night() then
        return "overworld_night"
    end
    return slug
end
