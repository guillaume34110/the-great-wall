-- tgw_shop : node "comptoir" dans la maison. Rightclick → formspec
-- dual-wallet (perso pour items, commun pour réparation mur/porte).

local S = core.get_translator("tgw_shop")
tgw_shop = {}
tgw_shop.S = S

local storage = core.get_mod_storage()

-- ---------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------

-- wallet : "personal" | "shared"
-- effect(player_name) → bool (true = appliqué)
tgw_shop.items = {
    {
        id = "bat",      label = "Extra Bat",        cost = 10, wallet = "personal",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:bat")
            return true
        end,
    },
    {
        id = "pistol",   label = "9mm Pistol",       cost = 25, wallet = "personal",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:pistol")
            return true
        end,
    },
    {
        id = "shotgun",  label = "Border Shotgun",   cost = 40, wallet = "personal",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:shotgun")
            return true
        end,
    },
    {
        id = "net",      label = "Capture Net",      cost = 8,  wallet = "personal",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_capture:net")
            return true
        end,
    },
    {
        id = "cucumber", label = "3x Cucumber",      cost = 4,  wallet = "personal",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:cucumber 3")
            return true
        end,
    },
    {
        id = "repair_wall", label = "Repair Wall (full)", cost = 50, wallet = "shared",
        effect = function()
            if not tgw_wall then return false end
            local b = tgw_map.get_wall_bounds()
            local t = b.thick
            local segments = {
                { x1 = b.x_min,         x2 = b.x_max,         z1 = b.z_min,         z2 = b.z_min + t - 1 },
                { x1 = b.x_min,         x2 = b.x_max,         z1 = b.z_max - t + 1, z2 = b.z_max         },
                { x1 = b.x_min,         x2 = b.x_min + t - 1, z1 = b.z_min,         z2 = b.z_max         },
                { x1 = b.x_max - t + 1, x2 = b.x_max,         z1 = b.z_min,         z2 = b.z_max         },
            }
            for _, s in ipairs(segments) do
                for x = s.x1, s.x2 do
                    for z = s.z1, s.z2 do
                        for y = b.y_min, b.y_max do
                            tgw_wall.repair({ x = x, y = y, z = z })
                        end
                    end
                end
            end
            return true
        end,
    },
    {
        id = "repair_door", label = "Repair Door (full)", cost = 80, wallet = "shared",
        effect = function()
            if not tgw_house then return false end
            -- Reset porte à HP max via damage négatif n'existe pas → set direct
            local dp = tgw_map.get_door_pos()
            local nodes = {
                dp,
                { x = dp.x, y = dp.y + 1, z = dp.z },
            }
            for _, p in ipairs(nodes) do
                if core.get_node(p).name == "air" then
                    core.set_node(p, { name = "tgw_house:door" })
                end
                core.get_meta(p):set_int("hp", tgw_core.config.door_hp)
            end
            return true
        end,
    },
}

-- ---------------------------------------------------------------------------
-- Formspec
-- ---------------------------------------------------------------------------

local function build_fs(player_name)
    local pers = tgw_economy.get_personal(player_name)
    local shar = tgw_economy.get_shared()

    local fs = "formspec_version[6]size[10,11]" ..
        "label[0.4,0.5;" .. core.formspec_escape(S("THE GREAT WALL — SHOP")) .. "]" ..
        "label[0.4,1.1;$ Personal: " .. pers .. "    $ Shared: " .. shar .. "]"

    local y = 1.8
    for _, it in ipairs(tgw_shop.items) do
        local tag = (it.wallet == "personal") and "[P]" or "[S]"
        fs = fs ..
            "label[0.4," .. y .. ";" .. tag .. " " ..
                core.formspec_escape(S(it.label)) .. " — " .. it.cost .. "$]" ..
            "button[7.0," .. (y - 0.3) .. ";2.5,0.8;buy_" .. it.id .. ";" ..
                core.formspec_escape(S("Buy")) .. "]"
        y = y + 0.9
    end

    fs = fs .. "button_exit[3.5,10.0;3,0.8;close;" .. core.formspec_escape(S("Close")) .. "]"
    return fs
end

function tgw_shop.show(player)
    if not player or not player:is_player() then return end
    core.show_formspec(player:get_player_name(), "tgw_shop:main", build_fs(player:get_player_name()))
end

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "tgw_shop:main" then return end
    local name = player:get_player_name()

    for _, it in ipairs(tgw_shop.items) do
        if fields["buy_" .. it.id] then
            local ok
            if it.wallet == "personal" then
                ok = tgw_economy.pay_personal(name, it.cost)
            else
                ok = tgw_economy.pay_shared(it.cost)
            end
            if not ok then
                core.chat_send_player(name, S("Insufficient @1 funds.",
                    it.wallet == "personal" and "personal" or "shared"))
                return true
            end
            local applied = it.effect(name)
            if not applied then
                -- remboursement
                if it.wallet == "personal" then
                    tgw_economy.add_personal(name, it.cost)
                else
                    tgw_economy.add_shared(it.cost)
                end
                core.chat_send_player(name, S("Purchase failed (effect)."))
                return true
            end
            core.chat_send_player(name, S("Bought @1 for @2$.", S(it.label), it.cost))
            tgw_shop.show(player)  -- refresh
            return true
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Node comptoir
-- ---------------------------------------------------------------------------

core.register_node("tgw_shop:counter", {
    description = S("Shop Counter"),
    tiles = {
        "default_steel_block.png",
        "default_steel_block.png",
        "default_steel_block.png^[colorize:#3366cc:120",
    },
    paramtype = "light",
    light_source = 6,
    groups = { tgw_shop = 1, not_in_creative_inventory = 1 },
    drop = "",
    can_dig = function() return false end,
    on_blast = function() end,
    on_rightclick = function(pos, node, clicker)
        if clicker and clicker:is_player() then tgw_shop.show(clicker) end
    end,
})

-- Placement automatique dans la maison (à côté du bouton START)
function tgw_shop.place_counter(force)
    if storage:get_int("placed") == 1 and not force then return end
    local hp = tgw_map.get_house_pos()  -- (0, 9, -20)
    -- intérieur côté sud, à gauche du bouton (bouton en x=0)
    local pos = { x = hp.x - 2, y = hp.y + 1, z = hp.z - 3 + 1 }
    core.set_node(pos, { name = "tgw_shop:counter" })
    storage:set_int("placed", 1)
end
local place_counter = tgw_shop.place_counter

core.register_on_joinplayer(function()
    core.after(2.0, place_counter)
end)

tgw_core.on("world_reset", function()
    storage:set_int("placed", 0)
end)

core.log("action", "[tgw_shop] loaded (" .. #tgw_shop.items .. " items)")
