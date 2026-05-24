-- tgw_map : Flat mapgen, border line, enemy spawn zone behind wall.
-- API: tgw_map.is_inside(pos), get_spawn_zone()

local MP = core.get_modpath(core.get_current_modname())
local S = core.get_translator("tgw_map")

tgw_map = {}
tgw_map.S = S

core.log("action", "[tgw_map] loaded")

-- TODO: implement
