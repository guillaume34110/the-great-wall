-- tgw_economy : Dual-wallet economy: personal (items) + shared (wall, defenses).
-- API: tgw_economy.get(name,kind), add(name,kind,amount), pay(name,kind,amount)

local MP = core.get_modpath(core.get_current_modname())
local S = core.get_translator("tgw_economy")

tgw_economy = {}
tgw_economy.S = S

core.log("action", "[tgw_economy] loaded")

-- TODO: implement
