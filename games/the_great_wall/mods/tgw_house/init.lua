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

-- Porte : solide, HP en meta, casser = defeat
core.register_node("tgw_house:door", {
    description = S("House Door"),
    tiles = { "doors_door_wood.png" },  -- texture du mod doors
    groups = { tgw_house = 1, tgw_door = 1, not_in_creative_inventory = 1 },
    drop = "",
    sounds = default.node_sound_wood_defaults(),
    on_construct = function(pos)
        core.get_meta(pos):set_int("hp", DOOR_HP)
    end,
    can_dig = function() return false end,
    on_blast = function() end,
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

    -- Porte : face nord (z = z1 = hp.z+3 = -17), centrée en X=0, hauteur 2 (y0..y0+1)
    local dx = 0
    local dz = z1  -- = -17, doit matcher DOOR_POS.z
    set({ x = dx, y = y0,     z = dz }, "tgw_house:door")
    set({ x = dx, y = y0 + 1, z = dz }, "tgw_house:door")
    -- meta HP partagé : on stocke sur le node du bas
    core.get_meta({ x = dx, y = y0, z = dz }):set_int("hp", DOOR_HP)
    core.get_meta({ x = dx, y = y0 + 1, z = dz }):set_int("hp", DOOR_HP)

    -- Bouton START : mur intérieur sud (z = z0+1), à l'intérieur
    set({ x = hp.x, y = y0 + 1, z = z0 + 1 }, "tgw_house:start_button")

    storage:set_int("built", 1)
    core.log("action", "[tgw_house] built at " .. core.pos_to_string(hp))
end

-- ---------------------------------------------------------------------------
-- Damage porte → defeat
-- ---------------------------------------------------------------------------

local DOOR_NODES = {
    { x = 0, y = tgw_map.GROUND_Y + 1,     z = -17 },
    { x = 0, y = tgw_map.GROUND_Y + 2, z = -17 },
}

function tgw_house.damage_door(amount)
    -- HP partagé : on lit/écrit sur les 2 nodes en miroir
    local pos = DOOR_NODES[1]
    local meta = core.get_meta(pos)
    local hp = meta:get_int("hp") - amount
    if hp <= 0 then
        for _, p in ipairs(DOOR_NODES) do
            core.remove_node(p)
        end
        tgw_core.emit("door_damaged", { hp_left = 0, dmg = amount, destroyed = true })
        if tgw_core.get_state() == tgw_core.STATE.RUN then
            tgw_core.set_state(tgw_core.STATE.DEFEAT)
            tgw_core.emit("run_lost", { wave_reached = -1 })  -- tgw_waves fournira l'index
        end
        return
    end
    for _, p in ipairs(DOOR_NODES) do
        core.get_meta(p):set_int("hp", hp)
    end
    tgw_core.emit("door_damaged", { hp_left = hp, dmg = amount, destroyed = false })
end

function tgw_house.get_door_hp()
    return core.get_meta(DOOR_NODES[1]):get_int("hp")
end

-- ---------------------------------------------------------------------------
-- Auto-build au premier joueur
-- ---------------------------------------------------------------------------

core.register_on_joinplayer(function(player)
    if not built() then
        core.after(1.5, function() tgw_house.build() end)
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
end)

core.log("action", "[tgw_house] loaded")
