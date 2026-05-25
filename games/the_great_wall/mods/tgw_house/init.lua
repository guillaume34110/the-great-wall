-- tgw_house : maison cozy 7×5×7, porte 200 PV (defeat trigger), bouton START.
-- API : tgw_house.build(), tgw_house.damage_door(amount)

local S = core.get_translator("tgw_house")
tgw_house = {}
tgw_house.S = S

local cfg     = tgw_core.config
local DOOR_HP = cfg.door_hp  -- 200
local storage = core.get_mod_storage()

-- ---------------------------------------------------------------------------
-- Nodes
-- ---------------------------------------------------------------------------

core.register_node("tgw_house:wood", {
    description = S("House Wood"),
    tiles = { "default_wood.png" },
    groups = { tgw_house = 1, not_in_creative_inventory = 1 },
    drop = "",
    sounds = default.node_sound_wood_defaults(),
    can_dig = function() return false end,
    on_blast = function() end,
})

core.register_node("tgw_house:floor", {
    description = S("House Floor"),
    tiles = { "default_wood.png^[colorize:#000000:40" },
    groups = { tgw_house = 1, not_in_creative_inventory = 1 },
    drop = "",
    sounds = default.node_sound_wood_defaults(),
    can_dig = function() return false end,
    on_blast = function() end,
})

core.register_node("tgw_house:roof", {
    description = S("House Roof"),
    tiles = { "default_tree_top.png" },
    groups = { tgw_house = 1, not_in_creative_inventory = 1 },
    drop = "",
    sounds = default.node_sound_wood_defaults(),
    can_dig = function() return false end,
    on_blast = function() end,
})

-- Porte : on délègue au mod `doors` (doors:door_wood = vraie porte ouvrable).
-- HP stocké dans mod_storage. Quand HP=0 → remove + DEFEAT.
-- `tgw_house:door` reste registered pour compat (anciens nodes du monde).

core.register_node("tgw_house:door", {
    description = S("House Door (legacy)"),
    tiles = { "doors_door_wood.png" },
    groups = { tgw_house = 1, tgw_door = 1, not_in_creative_inventory = 1 },
    drop = "",
    sounds = default.node_sound_wood_defaults(),
    can_dig = function() return false end,
    on_blast = function() end,
})

local function door_get_hp()
    local h = storage:get_int("door_hp")
    if h <= 0 and storage:get_string("door_init") == "" then
        h = DOOR_HP
        storage:set_int("door_hp", h)
        storage:set_string("door_init", "1")
    end
    return h
end

local function door_set_hp(h)
    storage:set_int("door_hp", h)
end

local function door_positions()
    return {
        { x = 0, y = tgw_map.GROUND_Y + 1, z = -17 },
        { x = 0, y = tgw_map.GROUND_Y + 2, z = -17 },
    }
end

local DOOR_VARIANTS = {
    ["doors:door_wood_a"] = true,
    ["doors:door_wood_b"] = true,
    ["doors:door_wood_c"] = true,
    ["doors:door_wood_d"] = true,
}

-- Place une vraie doors:door_wood (param2=2 = battant face nord, ouvre vers ext)
local function place_real_door()
    if door_get_hp() <= 0 then return end  -- détruite, ne pas re-spawn
    local pos  = door_positions()
    local bot, top = pos[1], pos[2]
    local nb = core.get_node(bot).name
    if DOOR_VARIANTS[nb] then return end  -- déjà OK
    core.remove_node(bot)
    core.remove_node(top)
    core.set_node(bot, { name = "doors:door_wood_a", param2 = 2 })
    core.set_node(top, { name = "doors:hidden",      param2 = 2 })
    core.get_meta(bot):set_int("state", 0)
    core.log("action", "[tgw_house] door upgraded to doors:door_wood_a")
end

tgw_house.place_real_door = place_real_door

-- Workbench position
local function workbench_pos()
    local hp = tgw_map.get_house_pos()
    return { x = hp.x - 2, y = hp.y, z = hp.z }
end

local function place_workbench()
    if not core.registered_nodes["tgw_combat:workbench"] then return end
    local p = workbench_pos()
    local cur = core.get_node(p).name
    if cur == "tgw_combat:workbench" then return end
    if cur == "ignore" then return end
    core.set_node(p, { name = "tgw_combat:workbench" })
    core.log("action", "[tgw_house] workbench placed @ " .. core.pos_to_string(p))
end

tgw_house.place_workbench = place_workbench

-- Migration robuste : emerge + retry jusqu'à ce que le chunk soit chargé
local function ensure_house_extras(retries)
    retries = retries or 30
    local bot = door_positions()[1]
    local n = core.get_node(bot).name
    if n == "ignore" then
        core.emerge_area(
            { x = bot.x - 2, y = bot.y - 2, z = bot.z - 2 },
            { x = bot.x + 4, y = bot.y + 4, z = bot.z + 4 }
        )
        if retries > 0 then
            core.after(1.0, function() ensure_house_extras(retries - 1) end)
        end
        return
    end
    place_real_door()
    place_workbench()
end

tgw_house.ensure_extras = ensure_house_extras

-- LBM : migration au chunk load (anciens tgw_house:door)
core.register_lbm({
    label = "tgw_house: upgrade legacy door",
    name  = "tgw_house:upgrade_door_v3",
    nodenames = { "tgw_house:door" },
    run_at_every_load = true,
    action = function(pos)
        local pp = door_positions()
        if pos.x == pp[1].x and pos.z == pp[1].z and
           (pos.y == pp[1].y or pos.y == pp[2].y) then
            core.remove_node(pp[1])
            core.remove_node(pp[2])
            core.set_node(pp[1], { name = "doors:door_wood_a", param2 = 2 })
            core.set_node(pp[2], { name = "doors:hidden",      param2 = 2 })
            core.get_meta(pp[1]):set_int("state", 0)
            core.log("action", "[tgw_house] LBM upgraded door @ " .. core.pos_to_string(pp[1]))
        else
            core.remove_node(pos)
        end
    end,
})

-- Au mod load : déclenche migration (retry intégré si chunk pas prêt)
core.after(3.0, function() ensure_house_extras() end)

-- Chat command de secours
core.register_chatcommand("fix_house", {
    description = "Force door + workbench placement",
    privs = { server = true },
    func = function(name)
        ensure_house_extras()
        return true, "house extras triggered"
    end,
})

-- Bouton START : rightclick en LOBBY → emit run_started
core.register_node("tgw_house:start_button", {
    description = S("START Button"),
    tiles = { "default_steel_block.png^[colorize:#cc0000:200" },
    paramtype = "light",
    light_source = 8,
    groups = { tgw_house = 1, not_in_creative_inventory = 1 },
    drop = "",
    can_dig = function() return false end,
    on_blast = function() end,
    on_rightclick = function(pos, node, clicker)
        if not clicker or not clicker:is_player() then return end
        local state = tgw_core.get_state()
        if state ~= tgw_core.STATE.LOBBY then
            core.chat_send_player(clicker:get_player_name(),
                S("Run already in progress (state=@1)", state))
            return
        end
        local players = {}
        for _, p in ipairs(core.get_connected_players()) do
            table.insert(players, p:get_player_name())
        end
        tgw_core.set_state(tgw_core.STATE.RUN)
        tgw_core.emit("run_started", { players = players })
        core.chat_send_all(S("RUN STARTED — 200 waves incoming. Defend the door."))
    end,
})

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

local function built() return storage:get_int("built") == 1 end

local function set(pos, name)
    core.set_node(pos, { name = name })
end

function tgw_house.build(force)
    if built() and not force then return end

    local hp     = tgw_map.get_house_pos()
    local sz     = tgw_map.HOUSE_SIZE  -- 7x5x7
    local door_p = tgw_map.get_door_pos()

    -- Footprint : hp est coin sud-ouest-bas. House occupe X[hp.x-3..hp.x+3], Y[hp.y..hp.y+4], Z[hp.z-3..hp.z+3]
    local x0, x1 = hp.x - 3, hp.x + 3
    local z0, z1 = hp.z - 3, hp.z + 3
    local y0, y1 = hp.y, hp.y + sz.y - 1  -- 9..13
    local y_roof = y1 + 1                 -- 14

    -- Sol
    for x = x0, x1 do
        for z = z0, z1 do
            set({ x = x, y = y0 - 1, z = z }, "tgw_house:floor")
        end
    end

    -- Murs (périmètre), creux à l'intérieur
    for x = x0, x1 do
        for z = z0, z1 do
            for y = y0, y1 do
                local on_perim = (x == x0 or x == x1 or z == z0 or z == z1)
                if on_perim then
                    set({ x = x, y = y, z = z }, "tgw_house:wood")
                else
                    set({ x = x, y = y, z = z }, "air")
                end
            end
        end
    end

    -- Toit plat
    for x = x0, x1 do
        for z = z0, z1 do
            set({ x = x, y = y_roof, z = z }, "tgw_house:roof")
        end
    end

    -- Porte : doors:door_wood_a + doors:hidden, centrée X=0, z=z1=-17
    local dx = 0
    local dz = z1  -- = -17, doit matcher DOOR_POS.z
    core.set_node({ x = dx, y = y0,     z = dz }, { name = "doors:door_wood_a", param2 = 2 })
    core.set_node({ x = dx, y = y0 + 1, z = dz }, { name = "doors:hidden",      param2 = 2 })
    core.get_meta({ x = dx, y = y0, z = dz }):set_int("state", 0)
    storage:set_int("door_hp", DOOR_HP)
    storage:set_string("door_init", "1")

    -- Bouton START : mur intérieur sud (z = z0+1), à l'intérieur
    set({ x = hp.x, y = y0 + 1, z = z0 + 1 }, "tgw_house:start_button")

    storage:set_int("built", 1)
    core.log("action", "[tgw_house] built at " .. core.pos_to_string(hp))
end

-- ---------------------------------------------------------------------------
-- Damage porte → defeat
-- ---------------------------------------------------------------------------

function tgw_house.damage_door(amount)
    local hp = door_get_hp() - amount
    if hp <= 0 then
        for _, p in ipairs(door_positions()) do
            core.remove_node(p)
        end
        door_set_hp(0)
        tgw_core.emit("door_damaged", { hp_left = 0, dmg = amount, destroyed = true })
        if tgw_core.get_state() == tgw_core.STATE.RUN then
            tgw_core.set_state(tgw_core.STATE.DEFEAT)
            tgw_core.emit("run_lost", { wave_reached = -1 })
        end
        return
    end
    door_set_hp(hp)
    tgw_core.emit("door_damaged", { hp_left = hp, dmg = amount, destroyed = false })
end

function tgw_house.get_door_hp()
    return door_get_hp()
end

-- ---------------------------------------------------------------------------
-- Auto-build au premier joueur
-- ---------------------------------------------------------------------------

core.register_on_joinplayer(function(player)
    if not built() then
        core.after(1.5, function()
            tgw_house.build()
            core.after(0.5, function() ensure_house_extras() end)
        end)
    else
        core.after(2.0, function() ensure_house_extras() end)
    end
    -- Repositionne le joueur au spawn défini
    core.after(0.5, function()
        if player and player:is_player() then
            player:set_pos(tgw_map.get_player_spawn())
        end
    end)
end)

tgw_core.on("world_reset", function()
    storage:set_int("built", 0)
    storage:set_int("door_hp", 0)
    storage:set_string("door_init", "")
end)

core.log("action", "[tgw_house] loaded")
