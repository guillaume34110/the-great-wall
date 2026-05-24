-- tgw_pipeline : Deportation pipe: tampon zone -> map exit. 50% return RNG, entry bonus > kill.
-- API: tgw_pipeline.enqueue(invader,player), on_exit()

local MP = core.get_modpath(core.get_current_modname())
local S = core.get_translator("tgw_pipeline")

tgw_pipeline = {}
tgw_pipeline.S = S

core.log("action", "[tgw_pipeline] loaded")

-- TODO: implement
