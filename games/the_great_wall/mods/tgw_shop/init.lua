-- tgw_shop : Formspec shop: buy weapons, repair materials, upgrades. Split wallets.
-- API: tgw_shop.show(player), register_item(def)

local MP = core.get_modpath(core.get_current_modname())
local S = core.get_translator("tgw_shop")

tgw_shop = {}
tgw_shop.S = S

core.log("action", "[tgw_shop] loaded")

-- TODO: implement
