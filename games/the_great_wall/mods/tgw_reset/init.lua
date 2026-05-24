-- tgw_reset : Server auto-reset on defeat/victory: wipe world, keep HoF, regen.
-- API: tgw_reset.schedule(reason)

local MP = core.get_modpath(core.get_current_modname())
local S = core.get_translator("tgw_reset")

tgw_reset = {}
tgw_reset.S = S

core.log("action", "[tgw_reset] loaded")

-- TODO: implement
