-- tgw_capture : filet non-létal. Hit invader → invader_captured + pipeline.

local S = core.get_translator("tgw_capture")
tgw_capture = {}
tgw_capture.S = S

-- ---------------------------------------------------------------------------
-- Outil : filet
-- ---------------------------------------------------------------------------

core.register_tool("tgw_capture:net", {
    description = S("Capture Net"),
    inventory_image = "default_paper.png^[colorize:#ffffff:200",
    -- on_use géré manuellement pour viser une entité
    on_use = function(itemstack, user, pointed_thing)
        if not user or not user:is_player() then return end
        if not pointed_thing or pointed_thing.type ~= "object" then return end
        local obj = pointed_thing.ref
        if not obj or not obj:get_luaentity() then return end
        local ent = obj:get_luaentity()
        if not ent.name or ent.name:sub(1, 12) ~= "tgw_invader:" then return end
        tgw_capture.capture(ent, user:get_player_name())
        return itemstack
    end,
})

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

function tgw_capture.capture(invader_ent, capturer_name)
    if not invader_ent or not invader_ent.object then return end
    if invader_ent._captured then return end
    invader_ent._captured = true

    tgw_core.emit("invader_captured", {
        invader  = invader_ent,
        capturer = capturer_name,
    })

    -- Envoi dans le pipeline
    if tgw_pipeline and tgw_pipeline.send then
        tgw_pipeline.send(invader_ent, capturer_name)
    else
        invader_ent.object:remove()
    end
end

core.log("action", "[tgw_capture] loaded")
