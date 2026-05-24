lumia_chargen = {}
lumia_chargen.modpath = minetest.get_modpath("lumia_chargen")

local function log(level, msg)
    minetest.log(level, "[lumia_chargen] " .. msg)
end
lumia_chargen.log = log

lumia_chargen._done_callbacks = {}
function lumia_chargen.register_on_done(fn)
    table.insert(lumia_chargen._done_callbacks, fn)
end

dofile(lumia_chargen.modpath .. "/races.lua")
dofile(lumia_chargen.modpath .. "/signs.lua")
-- apply.lua + formspec.lua : RPG chargen lourd hérité lumiaOpen.
-- Désactivé dans tgw — sélection guardian gérée par tgw_trump_skin.
-- races.lua reste chargé (utilisé par tgw_invader pour la génération d'ennemis).

log("action", "lumia_chargen chargé")
