-- tgw_shop : 2 comptoirs.
--   weapons   : armes & utilitaires (counters dans maison + pied de tours)
--   materials : matériaux & pièges (counter dédié près de la maison)
-- dual-wallet (perso pour items, commun pour réparation mur/porte).

local S = core.get_translator("tgw_shop")
tgw_shop = {}
tgw_shop.S = S

local storage = core.get_mod_storage()

-- ---------------------------------------------------------------------------
-- Helper : effet "donner un item"
-- ---------------------------------------------------------------------------
local function give(item)
    return function(name)
        local p = core.get_player_by_name(name); if not p then return false end
        p:get_inventory():add_item("main", item)
        return true
    end
end

-- ---------------------------------------------------------------------------
-- Catalogues
-- ---------------------------------------------------------------------------

-- wallet : "personal" | "shared"
-- effect(player_name) → bool (true = appliqué)
-- icon_item : itemstring affiché dans la liste (item_image)
tgw_shop.catalogues = {}

tgw_shop.catalogues.weapons = {
    {
        id = "bat",      label = "Extra Bat",        cost = 10, wallet = "personal",
        icon_item = "tgw_combat:bat",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:bat")
            return true
        end,
    },
    {
        id = "pistol",   label = "9mm Pistol",       cost = 25, wallet = "personal",
        icon_item = "tgw_combat:pistol",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:pistol")
            return true
        end,
    },
    {
        id = "shotgun",  label = "Border Shotgun",   cost = 40, wallet = "personal",
        icon_item = "tgw_combat:shotgun",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:shotgun")
            return true
        end,
    },
    {
        id = "net",      label = "Capture Net",      cost = 8,  wallet = "personal",
        icon_item = "tgw_capture:net",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_capture:net")
            return true
        end,
    },
    {
        id = "cucumber", label = "3x Cucumber",      cost = 4,  wallet = "personal",
        icon_item = "tgw_combat:cucumber",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:cucumber 3")
            return true
        end,
    },
    {
        id = "ar",       label = "Eagle AR-15",       cost = 75,  wallet = "personal",
        icon_item = "tgw_combat:ar",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:ar")
            return true
        end,
    },
    {
        id = "sniper",   label = "Lone Star Sniper",  cost = 110, wallet = "personal",
        icon_item = "tgw_combat:sniper",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:sniper")
            return true
        end,
    },
    {
        id = "minigun",  label = "Freedom Minigun",   cost = 180, wallet = "personal",
        icon_item = "tgw_combat:minigun",
        effect = function(name)
            local p = core.get_player_by_name(name); if not p then return false end
            p:get_inventory():add_item("main", "tgw_combat:minigun")
            return true
        end,
    },
}

-- ---------------------------------------------------------------------------
-- Matériaux & pièges (counter dédié près de la maison)
-- ---------------------------------------------------------------------------
tgw_shop.catalogues.materials = {
    {
        id = "trap_spikes", label = "Spike Trap",     cost = 35,  wallet = "personal",
        icon_item = "tgw_shop:trap_spikes",
        effect = give("tgw_shop:trap_spikes"),
    },
    {
        id = "trap_wire",   label = "Barbed Wire",    cost = 25,  wallet = "personal",
        icon_item = "tgw_shop:trap_wire",
        effect = give("tgw_shop:trap_wire"),
    },
    {
        id = "trap_mine",   label = "Land Mine",      cost = 120, wallet = "personal",
        icon_item = "tgw_shop:trap_mine",
        effect = give("tgw_shop:trap_mine"),
    },
    {
        id = "trap_spikes5", label = "5x Spike Trap", cost = 150, wallet = "shared",
        icon_item = "tgw_shop:trap_spikes",
        effect = give("tgw_shop:trap_spikes 5"),
    },
    {
        id = "trap_mine3",  label = "3x Land Mine",   cost = 320, wallet = "shared",
        icon_item = "tgw_shop:trap_mine",
        effect = give("tgw_shop:trap_mine 3"),
    },
    {
        id = "repair_wall", label = "Repair Wall (full)", cost = 50, wallet = "shared",
        icon_item = "tgw_wall:stone",
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
        icon_item = "doors:door_wood",
        effect = function()
            if not (tgw_house and tgw_house.repair_door_full) then return false end
            return tgw_house.repair_door_full()
        end,
    },
}

-- ---------------------------------------------------------------------------
-- Formspec
-- ---------------------------------------------------------------------------

local CAT_TITLES = {
    weapons   = S("WEAPONS SHOP"),
    materials = S("MATERIALS & TRAPS"),
}

local function build_fs(player_name, cat_key)
    local items = tgw_shop.catalogues[cat_key] or tgw_shop.catalogues.weapons
    local pers  = tgw_economy.get_personal(player_name)
    local shar  = tgw_economy.get_shared()

    local n      = #items
    local row_h  = 1.1
    local top_h  = 1.8
    local bot_h  = 1.4
    local height = top_h + n * row_h + bot_h
    local width  = 11

    local fs = "formspec_version[6]size[" .. width .. "," .. height .. "]" ..
        "bgcolor[#202028FA;true]" ..
        "label[0.5,0.5;" .. core.formspec_escape(CAT_TITLES[cat_key] or "SHOP") .. "]" ..
        "box[0.4,0.9;" .. (width - 0.8) .. ",0.6;#3a3a4a]" ..
        "label[0.6,1.2;" .. core.formspec_escape(
            S("Personal") .. ": " .. pers .. " $    |    " ..
            S("Shared")   .. ": " .. shar .. " $") .. "]"

    local y = top_h
    for _, it in ipairs(items) do
        local tag      = (it.wallet == "personal") and S("perso") or S("commun")
        local row_col  = (it.wallet == "personal") and "#2a3530" or "#352f2a"
        fs = fs ..
            "box[0.4," .. y .. ";" .. (width - 0.8) .. ",0.9;" .. row_col .. "]" ..
            "item_image[0.55," .. (y + 0.05) .. ";0.8,0.8;" .. (it.icon_item or "") .. "]" ..
            "label[1.6," .. (y + 0.45) .. ";" ..
                core.formspec_escape(S(it.label)) .. "]" ..
            "label[6.3," .. (y + 0.45) .. ";" .. it.cost .. " $]" ..
            "label[7.4," .. (y + 0.45) .. ";" ..
                core.formspec_escape("(" .. tag .. ")") .. "]" ..
            "button[8.7," .. (y + 0.05) .. ";1.9,0.8;buy_" .. it.id .. ";" ..
                core.formspec_escape(S("Buy")) .. "]"
        y = y + row_h
    end

    fs = fs .. "button_exit[" .. ((width - 3) / 2) .. "," .. (y + 0.3) .. ";3,0.8;close;" ..
        core.formspec_escape(S("Close")) .. "]"
    return fs
end

function tgw_shop.show(player, cat_key)
    if not player or not player:is_player() then return end
    cat_key = cat_key or "weapons"
    core.show_formspec(player:get_player_name(),
        "tgw_shop:" .. cat_key,
        build_fs(player:get_player_name(), cat_key))
end

core.register_on_player_receive_fields(function(player, formname, fields)
    local cat_key = formname:match("^tgw_shop:(.+)$")
    if not cat_key or not tgw_shop.catalogues[cat_key] then return end
    local name  = player:get_player_name()
    local items = tgw_shop.catalogues[cat_key]

    for _, it in ipairs(items) do
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
                if it.wallet == "personal" then
                    tgw_economy.add_personal(name, it.cost)
                else
                    tgw_economy.add_shared(it.cost)
                end
                core.chat_send_player(name, S("Purchase failed (effect)."))
                return true
            end
            core.chat_send_player(name, S("Bought @1 for @2$.", S(it.label), it.cost))
            tgw_shop.show(player, cat_key)  -- refresh
            return true
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Pièges (nodes placés au sol par le joueur)
-- ---------------------------------------------------------------------------

local function damage_invader(obj, dmg)
    if not obj or not obj.get_luaentity then return end
    local ent = obj:get_luaentity()
    if not ent or not ent.name then return end
    if not ent.name:find("^tgw_invader:") then return end
    local hp = obj:get_hp() - dmg
    if hp <= 0 then
        tgw_core.emit("invader_killed", { invader = ent, killer = nil })
        obj:remove()
    else
        obj:set_hp(hp)
    end
end

local function for_invaders_around(pos, radius, fn)
    for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
        local ent = obj:get_luaentity()
        if ent and ent.name and ent.name:find("^tgw_invader:") then
            fn(obj, ent)
        end
    end
end

core.register_node("tgw_shop:trap_spikes", {
    description = S("Spike Trap"),
    tiles = { "tgw_shop_trap_spikes.png" },
    drawtype  = "nodebox",
    paramtype = "light",
    walkable  = true,
    sunlight_propagates = true,
    node_box  = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.25, 0.5 } },
    selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.25, 0.5 } },
    groups    = { tgw_trap = 1, oddly_breakable_by_hand = 3 },
    damage_per_second = 2,
})

core.register_node("tgw_shop:trap_wire", {
    description = S("Barbed Wire"),
    tiles = { "tgw_shop_trap_wire.png" },
    drawtype  = "nodebox",
    paramtype = "light",
    walkable  = false,
    sunlight_propagates = true,
    node_box  = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.35, 0.5 } },
    selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.35, 0.5 } },
    groups    = { tgw_trap = 1, oddly_breakable_by_hand = 3 },
    damage_per_second = 1,
})

core.register_node("tgw_shop:trap_mine", {
    description = S("Land Mine"),
    tiles = { "tgw_shop_trap_mine.png" },
    drawtype  = "nodebox",
    paramtype = "light",
    walkable  = false,
    sunlight_propagates = true,
    node_box  = { type = "fixed", fixed = { -0.3, -0.5, -0.3, 0.3, -0.2, 0.3 } },
    selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.2, 0.5 } },
    groups    = { tgw_trap = 1, tgw_mine = 1, oddly_breakable_by_hand = 3 },
})

-- ABM : pièges spikes/wire — damage invaders en contact
core.register_abm({
    label = "tgw_shop:trap_damage",
    nodenames = { "tgw_shop:trap_spikes", "tgw_shop:trap_wire" },
    interval = 1.0,
    chance   = 1,
    action   = function(pos, node)
        local dmg = (node.name == "tgw_shop:trap_spikes") and 6 or 3
        for_invaders_around(pos, 1.2, function(obj) damage_invader(obj, dmg) end)
    end,
})

-- ABM : mine — explose si invader proche
core.register_abm({
    label = "tgw_shop:trap_mine_trigger",
    nodenames = { "tgw_shop:trap_mine" },
    interval = 0.5,
    chance   = 1,
    action   = function(pos)
        local triggered = false
        for_invaders_around(pos, 1.5, function() triggered = true end)
        if not triggered then return end
        core.set_node(pos, { name = "air" })
        core.add_particlespawner({
            amount = 40, time = 0.2,
            minpos = vector.subtract(pos, 0.5), maxpos = vector.add(pos, 0.5),
            minvel = { x = -3, y = 2, z = -3 }, maxvel = { x = 3, y = 6, z = 3 },
            minexptime = 0.3, maxexptime = 0.8,
            minsize = 2, maxsize = 4,
            texture = "default_steel_block.png^[colorize:#ff6622:200",
            glow = 14,
        })
        core.sound_play("tnt_explode",
            { pos = pos, gain = 1.0, max_hear_distance = 32 }, true)
        for_invaders_around(pos, 3.5, function(obj) damage_invader(obj, 55) end)
    end,
})

-- ---------------------------------------------------------------------------
-- Mystery Box (style CoD Zombies) — caisse arme weapons
-- Click → débit, lid s'ouvre, sprite arme tourne au-dessus, ralentit sur le prix,
-- reste flottant 30s. Punch (ou rightclick) du propriétaire = ramasse.
-- Après cleanup, caisse repasse à closed (réutilisable, contrairement à tgw_wall).
-- ---------------------------------------------------------------------------
local GACHA_COST    = 50
local SPIN_DURATION = 2.5
local REVEAL_TIME   = 30.0
local WEAPON_POOL = {}
for _, it in ipairs(tgw_shop.catalogues.weapons) do
    table.insert(WEAPON_POOL, it.icon_item)
end
-- Bonus : accessoires (15% effectif via duplication ratio).
-- Pool unique = armes + accessoires. Accessoires plus rares (1 entry chacun).
if tgw_combat and tgw_combat.accessories then
    for id, _ in pairs(tgw_combat.accessories) do
        table.insert(WEAPON_POOL, "tgw_combat:acc_" .. id)
    end
end

local crate_busy = {}
local function ckey(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end

core.register_entity("tgw_shop:gacha_spinner", {
    initial_properties = {
        visual               = "wielditem",
        wield_item           = "default:cobble",
        visual_size          = { x = 0.5, y = 0.5 },
        physical             = false,
        collide_with_objects = false,
        pointable            = true,
        static_save          = false,
        glow                 = 12,
    },
    timer    = 0,
    swap_t   = 0,
    swap_int = 0.06,
    phase    = "spin",
    prize    = nil,
    owner    = nil,
    crate    = nil,
    bob_t    = 0,

    on_activate = function(self, staticdata)
        if not staticdata or staticdata == "" then
            self.object:remove(); return
        end
        local d = core.deserialize(staticdata)
        if not d then self.object:remove(); return end
        self.prize = d.prize
        self.owner = d.owner
        self.crate = d.crate
    end,

    on_step = function(self, dtime)
        self.timer = self.timer + dtime
        self.bob_t = self.bob_t + dtime

        local spin_speed = self.phase == "spin" and 6.0 or 1.0
        self.object:set_yaw(self.object:get_yaw() + spin_speed * dtime)

        if self.crate then
            local base_y = self.crate.y + 1.2
            local off    = math.sin(self.bob_t * 2.0) * 0.08
            local p      = self.object:get_pos()
            self.object:set_pos({ x = p.x, y = base_y + off, z = p.z })
        end

        if self.phase == "spin" then
            self.swap_t = self.swap_t + dtime
            if self.swap_t >= self.swap_int then
                self.swap_t = 0
                local t = math.min(1, self.timer / SPIN_DURATION)
                self.swap_int = 0.06 + t * t * 0.35
                local item = WEAPON_POOL[math.random(1, #WEAPON_POOL)]
                self.object:set_properties({ wield_item = item })
                core.sound_play("default_click",
                    { object = self.object, gain = 0.4, max_hear_distance = 16 }, true)
            end
            if self.timer >= SPIN_DURATION then
                self.phase = "reveal"
                self.timer = 0
                self.object:set_properties({
                    wield_item  = self.prize,
                    visual_size = { x = 0.7, y = 0.7 },
                })
                core.sound_play("default_dig_metal",
                    { pos = self.object:get_pos(), gain = 1.0,
                      max_hear_distance = 24 }, true)
                core.add_particlespawner({
                    amount = 60, time = 0.6,
                    minpos = vector.subtract(self.object:get_pos(), {x=0.4,y=0.4,z=0.4}),
                    maxpos = vector.add(self.object:get_pos(),      {x=0.4,y=0.4,z=0.4}),
                    minvel = { x = -1, y = 1,  z = -1 },
                    maxvel = { x =  1, y = 3,  z =  1 },
                    minacc = { x =  0, y = -2, z =  0 },
                    maxacc = { x =  0, y = -2, z =  0 },
                    minexptime = 0.6, maxexptime = 1.2,
                    minsize = 1.2, maxsize = 2.5,
                    texture = "default_gold_lump.png",
                    glow = 12,
                })
                if self.owner then
                    local label = core.registered_items[self.prize]
                        and core.registered_items[self.prize].description
                        or self.prize
                    core.chat_send_player(self.owner,
                        core.colorize("#66ccff",
                            "[Arsenal] " .. S("Punch to take : @1", label)))
                end
            end
        elseif self.phase == "reveal" then
            if self.timer >= REVEAL_TIME then
                self.phase = "done"
                self:_cleanup_crate()
                self.object:remove()
            end
        end
    end,

    on_punch = function(self, puncher)
        if self.phase ~= "reveal" then return end
        if not (puncher and puncher:is_player()) then return end
        local pname = puncher:get_player_name()
        if pname ~= self.owner then
            core.chat_send_player(pname,
                S("Not your loot — wait the despawn."))
            return
        end
        puncher:get_inventory():add_item("main", self.prize)
        core.sound_play("default_place_node",
            { pos = self.object:get_pos(), gain = 0.7 }, true)
        self.phase = "done"
        self:_cleanup_crate()
        self.object:remove()
    end,

    on_rightclick = function(self, clicker)
        self.on_punch(self, clicker)
    end,

    _cleanup_crate = function(self)
        if not self.crate then return end
        crate_busy[ckey(self.crate)] = nil
        -- Réutilisable : repasse à closed (au lieu de empty comme tgw_wall).
        if core.get_node(self.crate).name == "tgw_shop:counter_open" then
            core.set_node(self.crate, { name = "tgw_shop:counter" })
        end
    end,
})

local function spawn_weapon_spinner(crate_pos, prize, owner)
    local p = { x = crate_pos.x + 0.5, y = crate_pos.y + 1.2, z = crate_pos.z + 0.5 }
    return core.add_entity(p, "tgw_shop:gacha_spinner",
        core.serialize({ prize = prize, owner = owner, crate = crate_pos }))
end

-- ---------------------------------------------------------------------------
-- Nodes comptoirs
-- ---------------------------------------------------------------------------

core.register_node("tgw_shop:counter", {
    description = S("Weapons Mystery Box (@1$)", GACHA_COST),
    tiles = {
        "default_chest_top.png^[colorize:#3366cc:120",
        "default_chest_top.png^[colorize:#3366cc:120",
        "default_chest_side.png^[colorize:#3366cc:120",
        "default_chest_side.png^[colorize:#3366cc:120",
        "default_chest_side.png^[colorize:#3366cc:120",
        "default_chest_front.png^[colorize:#3366cc:120",
    },
    paramtype     = "light",
    light_source  = 8,
    groups        = { tgw_shop = 1, not_in_creative_inventory = 1 },
    drop          = "",
    can_dig       = function() return false end,
    on_blast      = function() end,
    on_rightclick = function(pos, _, clicker)
        if not (clicker and clicker:is_player()) then return end
        local name = clicker:get_player_name()
        if crate_busy[ckey(pos)] then
            core.chat_send_player(name, S("Box busy — wait."))
            return
        end
        if not tgw_economy.pay_personal(name, GACHA_COST) then
            core.chat_send_player(name,
                S("Need @1$ personal to roll.", GACHA_COST))
            return
        end
        crate_busy[ckey(pos)] = true
        core.set_node(pos, { name = "tgw_shop:counter_open" })
        core.sound_play("default_chest_open",
            { pos = pos, gain = 0.9, max_hear_distance = 16 }, true)
        local prize = WEAPON_POOL[math.random(1, #WEAPON_POOL)]
        spawn_weapon_spinner(pos, prize, name)
    end,
    on_punch = function(pos, _, puncher)
        if puncher and puncher:is_player() then
            local n = core.get_node(pos)
            local def = core.registered_nodes[n.name]
            if def and def.on_rightclick then
                def.on_rightclick(pos, n, puncher)
            end
        end
    end,
})

core.register_node("tgw_shop:counter_open", {
    description = S("Weapons Mystery Box (open)"),
    tiles = {
        "default_chest_inside.png^[colorize:#3366cc:140",
        "default_chest_top.png^[colorize:#3366cc:120",
        "default_chest_side.png^[colorize:#3366cc:120",
        "default_chest_side.png^[colorize:#3366cc:120",
        "default_chest_side.png^[colorize:#3366cc:120",
        "default_chest_front.png^[colorize:#3366cc:140",
    },
    paramtype    = "light",
    light_source = 12,
    groups       = { tgw_shop = 1, not_in_creative_inventory = 1 },
    drop         = "",
    can_dig      = function() return false end,
    on_blast     = function() end,
})

-- Recovery : si une caisse est restée ouverte (crash mid-spin, entité perdue),
-- la repasse à closed quand le chunk se recharge.
core.register_lbm({
    label = "tgw_shop:reset_stuck_open",
    name  = "tgw_shop:reset_stuck_open",
    nodenames = { "tgw_shop:counter_open" },
    run_at_every_load = true,
    action = function(pos)
        core.set_node(pos, { name = "tgw_shop:counter" })
    end,
})

core.register_node("tgw_shop:counter_materials", {
    description = S("Materials & Traps Shop"),
    tiles = {
        "tgw_shop_counter_mat.png",
        "tgw_shop_counter_mat.png",
        "tgw_shop_counter_mat.png",
    },
    paramtype = "light",
    light_source = 6,
    groups = { tgw_shop = 1, not_in_creative_inventory = 1 },
    drop = "",
    can_dig = function() return false end,
    on_blast = function() end,
    on_rightclick = function(pos, node, clicker)
        if clicker and clicker:is_player() then tgw_shop.show(clicker, "materials") end
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

-- Caisse shop au pied de chaque tour, à côté de l'entrée de spirale
function tgw_shop.place_tower_counters(force)
    if storage:get_int("placed_towers") == 1 and not force then return end
    if not tgw_map then return end
    local b      = tgw_map.get_wall_bounds()
    local towers = tgw_map.get_towers()
    for _, t in pairs(towers) do
        local at_s         = (t.z_min == b.z_min)
        local entry_x      = math.floor((t.x_min + t.x_max) / 2)
        local inner_face_z = at_s and t.z_max or t.z_min
        local inside_dz    = at_s and -1 or 1
        -- 2 cases à l'intérieur depuis l'entrée, offset +1 x → libre de la spirale
        local pos = { x = entry_x + 1, y = b.y_min, z = inner_face_z + 2 * inside_dz }
        core.set_node(pos, { name = "tgw_shop:counter" })
    end
    storage:set_int("placed_towers", 1)
end
local place_tower_counters = tgw_shop.place_tower_counters

-- Counter matériaux à l'extérieur de la maison, côté est de la porte
function tgw_shop.place_materials_counter(force)
    if storage:get_int("placed_materials") == 1 and not force then return end
    local hp = tgw_map.get_house_pos()  -- (0, 9, -20)
    -- Porte au nord à z=-17 → 2 cases nord de la porte, 2 cases à l'est
    local pos = { x = hp.x + 2, y = hp.y + 1, z = hp.z + 5 }
    core.set_node(pos, { name = "tgw_shop:counter_materials" })
    storage:set_int("placed_materials", 1)
end
local place_materials_counter = tgw_shop.place_materials_counter

core.register_on_joinplayer(function()
    core.after(2.0, place_counter)
    core.after(2.3, place_materials_counter)
    core.after(2.5, place_tower_counters)
end)

tgw_core.on("world_reset", function()
    storage:set_int("placed", 0)
    storage:set_int("placed_materials", 0)
    storage:set_int("placed_towers", 0)
end)

do
    local w = #tgw_shop.catalogues.weapons
    local m = #tgw_shop.catalogues.materials
    core.log("action", "[tgw_shop] loaded (weapons=" .. w .. ", materials=" .. m .. ")")
end
