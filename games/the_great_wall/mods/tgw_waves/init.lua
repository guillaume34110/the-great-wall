-- tgw_waves : 200-wave scripted runs, difficulty tiers, night-bonus, player-count scaling.
-- API: tgw_waves.start_run(), next_wave(), current_wave

local MP = core.get_modpath(core.get_current_modname())
local S = core.get_translator("tgw_waves")

tgw_waves = {}
tgw_waves.S = S

core.log("action", "[tgw_waves] loaded")

-- TODO: implement
