-- tgw_invader : Border-crosser entity: pathfinding, wall-breaking, tunneling, types.
-- API: tgw_invader.spawn(pos,type), types = {runner, tank, digger}

local MP = core.get_modpath(core.get_current_modname())
local S = core.get_translator("tgw_invader")

tgw_invader = {}
tgw_invader.S = S

core.log("action", "[tgw_invader] loaded")

-- TODO: implement
