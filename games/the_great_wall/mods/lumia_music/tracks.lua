-- Catalogue des pistes. Une "track" = un slug logique + N variants OGG.
-- Le slug est aussi le nom de la sound spec Luanti (lumia_music_<slug>[_a|_b]).
-- priority: plus haut = écrase les pistes de priorité inférieure.
-- type: "loop" (boucle ambiance) ou "stinger" (one-shot, joué par-dessus).

local M = {}
lumia_music.tracks = M

local T = {
    -- type=loop boucle indéfiniment ; type=stinger joue une fois et libère
    -- le slot après `duration` secondes, l'ambient reprend ensuite.
    main_theme       = {priority =  5, type = "stinger", gain = 0.55, duration = 222, variants = {""}},
    haven            = {priority = 10, type = "loop",    gain = 0.50, variants = {"_a", "_b"}},
    overworld_day    = {priority = 20, type = "loop",    gain = 0.40, variants = {"_a", "_b"}},
    overworld_night  = {priority = 22, type = "loop",    gain = 0.45, variants = {"_a", "_b"}},
    forest           = {priority = 25, type = "loop",    gain = 0.45, variants = {"_a", "_b"}},
    desert           = {priority = 25, type = "loop",    gain = 0.45, variants = {"_a", "_b"}},
    coast            = {priority = 25, type = "loop",    gain = 0.45, variants = {"_a", "_b"}},
    mountain         = {priority = 25, type = "loop",    gain = 0.45, variants = {"_a", "_b"}},
    village          = {priority = 30, type = "loop",    gain = 0.50, variants = {"_a", "_b"}},
    dungeon          = {priority = 40, type = "loop",    gain = 0.55, variants = {"_a", "_b"}},
    lore             = {priority = 60, type = "stinger", gain = 0.55, duration = 359, variants = {""}},
    combat           = {priority = 70, type = "loop",    gain = 0.60, variants = {"_a", "_b"}},
    boss             = {priority = 80, type = "loop",    gain = 0.65, variants = {"_a", "_b"}},
    -- stingers one-shot
    discover         = {priority = 100, type = "stinger", gain = 0.70, duration = 97,  variants = {""}},
    waystone         = {priority = 100, type = "stinger", gain = 0.70, duration = 143, variants = {""}},
    death            = {priority = 100, type = "stinger", gain = 0.80, duration = 206, variants = {""}},
    victory          = {priority = 100, type = "stinger", gain = 0.75, duration = 248, variants = {""}},
    credits          = {priority = 100, type = "stinger", gain = 0.70, duration = 119, variants = {""}},
}

function M.get(slug)
    return T[slug]
end

function M.list()
    local out = {}
    for k in pairs(T) do out[#out + 1] = k end
    return out
end

-- Renvoie le nom de sound complet à passer à minetest.sound_play.
function M.pick_sound(slug)
    local def = T[slug]
    if not def then return nil end
    local v = def.variants[math.random(#def.variants)]
    return "lumia_music_" .. slug .. v, def
end
