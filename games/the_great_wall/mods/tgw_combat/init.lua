-- tgw_combat : armes létales + loadout starter.
-- L'arme tape directement via tool_capabilities ; tgw_invader.on_punch
-- gère HP + émet invader_killed.

local S = core.get_translator("tgw_combat")
tgw_combat = {}
tgw_combat.S = S

-- ---------------------------------------------------------------------------
-- Bat patriotique : melee rapide
-- ---------------------------------------------------------------------------

core.register_tool("tgw_combat:bat", {
    description = S("Patriot Bat"),
    inventory_image = "default_tool_steelsword.png^[colorize:#996633:140",
    tool_capabilities = {
        full_punch_interval = 0.6,
        max_drop_level = 1,
        groupcaps = {},
        damage_groups = { fleshy = 15 },
    },
    sound = { breaks = "default_tool_breaks" },
})

-- Concombre starter : nourriture (heal 4 PV), pas une arme
core.register_craftitem("tgw_combat:cucumber", {
    description = S("Border Cucumber"),
    inventory_image = "default_apple.png^[colorize:#338833:180",
    on_use = core.item_eat(4),
})

-- ---------------------------------------------------------------------------
-- Loadout starter (join + respawn)
-- ---------------------------------------------------------------------------

local function give_loadout(player)
    local inv = player:get_inventory()
    inv:set_list("main", {})
    inv:add_item("main", "tgw_combat:bat")
    inv:add_item("main", "tgw_combat:cucumber 3")
    if core.registered_items["tgw_capture:net"] then
        inv:add_item("main", "tgw_capture:net")
    end
end

tgw_combat.give_loadout = give_loadout

core.register_on_joinplayer(function(player)
    core.after(0.3, function()
        if player and player:is_player() then give_loadout(player) end
    end)
end)

core.register_on_respawnplayer(function(player)
    -- À poil + cooldown : on flush, on attend, on redonne
    player:get_inventory():set_list("main", {})
    core.after(tgw_core.config.respawn_cooldown, function()
        if player and player:is_player() then give_loadout(player) end
    end)
    return false  -- spawn par défaut, tgw_house repositionne au join
end)

core.log("action", "[tgw_combat] loaded")
