-- tgw_hof : Hall of Fame persistent across world resets.
-- API: tgw_hof.record(player_names, wave_reached, victory), top()

local MP = core.get_modpath(core.get_current_modname())
local S = core.get_translator("tgw_hof")

tgw_hof = {}
tgw_hof.S = S

core.log("action", "[tgw_hof] loaded")

-- TODO: implement
