lumia_music = {}

local function settings_bool(k, d)
    local v = minetest.settings:get_bool(k)
    if v == nil then return d end
    return v
end

local ENABLED = settings_bool("lumia.music_enabled", true)
if not ENABLED then
    minetest.log("action", "[lumia_music] disabled via lumia.music_enabled=false")
    return
end

local MP = minetest.get_modpath("lumia_music")
dofile(MP .. "/tracks.lua")
dofile(MP .. "/triggers.lua")
dofile(MP .. "/state.lua")

local S = lumia_music.state
local tracks = lumia_music.tracks

minetest.register_on_joinplayer(function(player)
    S.init_player(player)
    local name = player:get_player_name()
    -- Intro: main_theme one-shot. L'ambient prend le relais à expiration.
    minetest.after(1.0, function()
        if minetest.get_player_by_name(name) then
            S.play_stinger(name, "main_theme")
        end
    end)
end)

minetest.register_on_leaveplayer(function(player)
    S.remove_player(player:get_player_name())
end)

minetest.register_on_dieplayer(function(player)
    S.play_stinger(player:get_player_name(), "death")
end)

minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change < 0 and reason and reason.type ~= "drown" and reason.type ~= "fall" then
        S.mark_combat(player:get_player_name())
    end
end, false)

minetest.register_globalstep(function(dtime)
    S.on_step(dtime)
end)

-- API publique: déclenche un stinger pour un joueur (utilisé par d'autres mods).
function lumia_music.play_stinger(player_name, slug)
    S.play_stinger(player_name, slug)
end

function lumia_music.set_boss(player_name, on, duration)
    if on then
        S.mark_boss(player_name, duration)
    else
        local st = S.get(player_name)
        if st then st.boss_until = 0 end
    end
end

minetest.register_chatcommand("lumia_music_test", {
    description = "Joue un stinger ou bascule l'ambiance: <slug>",
    privs = {server = true},
    func = function(name, param)
        local slug = (param or ""):trim()
        if slug == "" then
            return false, "slugs: " .. table.concat(tracks.list(), ", ")
        end
        if not tracks.get(slug) then
            return false, "slug inconnu: " .. slug
        end
        S.play_stinger(name, slug)
        return true, "joué: " .. slug
    end,
})

minetest.register_chatcommand("lumia_music_status", {
    description = "Affiche l'ambiance courante",
    func = function(name)
        local st = S.get(name)
        if not st then return false, "non initialisé" end
        return true, string.format("ambient=%s combat_in=%.1fs boss_in=%.1fs",
            tostring(st.ambient_slug),
            math.max(0, st.combat_until - minetest.get_us_time() / 1e6),
            math.max(0, st.boss_until - minetest.get_us_time() / 1e6))
    end,
})

minetest.log("action", "[lumia_music] loaded, " .. #tracks.list() .. " tracks")
