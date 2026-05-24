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
dofile(lumia_chargen.modpath .. "/apply.lua")
dofile(lumia_chargen.modpath .. "/formspec.lua")

log("action", "lumia_chargen chargé")
