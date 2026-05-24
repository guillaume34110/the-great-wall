-- tgw_wall : enceinte carrée 150×150, 4 d'épaisseur, créneaux + tours coin + échelle.
-- HP par node (meta), génération via VoxelManip.
-- API : tgw_wall.build(force), tgw_wall.damage(pos, amount), tgw_wall.repair(pos, amount)

local S = core.get_translator("tgw_wall")
tgw_wall = {}
tgw_wall.S = S

local cfg     = tgw_core.config
local NODE_HP = cfg.wall_node_hp  -- 50
local storage = core.get_mod_storage()

-- ---------------------------------------------------------------------------
-- Nodes
-- ---------------------------------------------------------------------------

core.register_node("tgw_wall:stone", {
    description = S("Rampart Stone"),
    tiles = { "default_stone_block.png" },
    groups = { tgw_wall = 1, not_in_creative_inventory = 1 },
    drop = "",
    sounds = default.node_sound_stone_defaults(),
    on_construct = function(pos)
        core.get_meta(pos):set_int("hp", NODE_HP)
    end,
    can_dig = function() return false end,
    on_blast = function() end,
})

core.register_node("tgw_wall:tower", {
    description = S("Tower Stone"),
    tiles = { "default_stone_block.png^[colorize:#222244:60" },
    groups = { tgw_wall = 1, tgw_tower = 1, not_in_creative_inventory = 1 },
    drop = "",
    sounds = default.node_sound_stone_defaults(),
    on_construct = function(pos)
        core.get_meta(pos):set_int("hp", NODE_HP * 2)  -- tours plus solides
    end,
    can_dig = function() return false end,
    on_blast = function() end,
})

-- ---------------------------------------------------------------------------
-- Helpers VoxelManip
-- ---------------------------------------------------------------------------

local function vm_fill_box(vm, area, data, p1, p2, c_id)
    for z = p1.z, p2.z do
        for y = p1.y, p2.y do
            for x = p1.x, p2.x do
                local idx = area:index(x, y, z)
                if idx then data[idx] = c_id end
            end
        end
    end
end

local function set_meta_box(p1, p2, hp)
    for z = p1.z, p2.z do
        for y = p1.y, p2.y do
            for x = p1.x, p2.x do
                core.get_meta({ x = x, y = y, z = z }):set_int("hp", hp)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

local function wall_built() return storage:get_int("built") == 1 end

function tgw_wall.build(force)
    if wall_built() and not force then return end

    local b      = tgw_map.get_wall_bounds()
    local thick  = b.thick
    local towers = tgw_map.get_towers()
    local crenel_y = tgw_map.CRENEL_Y
    local tower_top = tgw_map.TOWER_TOP_Y

    local c_wall  = core.get_content_id("tgw_wall:stone")
    local c_tower = core.get_content_id("tgw_wall:tower")
    local c_air   = core.get_content_id("air")

    -- Bounding total : englobe tours (un peu plus haut que le mur)
    local p1 = { x = b.x_min, y = b.y_min,    z = b.z_min }
    local p2 = { x = b.x_max, y = tower_top, z = b.z_max }

    local vm = core.get_voxel_manip()
    local emin, emax = vm:read_from_map(p1, p2)
    local area = VoxelArea:new{ MinEdge = emin, MaxEdge = emax }
    local data = vm:get_data()

    -- ---------- 1. Perimetre 4 segments ----------
    -- Sud (z = z_min .. z_min+thick-1)
    vm_fill_box(vm, area, data,
        { x = b.x_min, y = b.y_min, z = b.z_min },
        { x = b.x_max, y = b.y_max, z = b.z_min + thick - 1 }, c_wall)
    -- Nord
    vm_fill_box(vm, area, data,
        { x = b.x_min, y = b.y_min, z = b.z_max - thick + 1 },
        { x = b.x_max, y = b.y_max, z = b.z_max }, c_wall)
    -- Ouest
    vm_fill_box(vm, area, data,
        { x = b.x_min, y = b.y_min, z = b.z_min },
        { x = b.x_min + thick - 1, y = b.y_max, z = b.z_max }, c_wall)
    -- Est
    vm_fill_box(vm, area, data,
        { x = b.x_max - thick + 1, y = b.y_min, z = b.z_min },
        { x = b.x_max, y = b.y_max, z = b.z_max }, c_wall)

    -- ---------- 2. Créneaux (y = crenel_y) sur les 4 murs ----------
    -- Périmètre extérieur uniquement (1 cube d'épaisseur côté extérieur)
    -- Alternance plein/vide modulo 2
    local function crenel_at(x, z)
        local idx = area:index(x, crenel_y, z)
        if idx then data[idx] = c_wall end
    end
    -- Sud (z = b.z_min) et Nord (z = b.z_max) : alterner sur X
    for x = b.x_min, b.x_max do
        if ((x - b.x_min) % 2) == 0 then
            crenel_at(x, b.z_min)
            crenel_at(x, b.z_max)
        end
    end
    -- Ouest (x = b.x_min) et Est (x = b.x_max) : alterner sur Z
    for z = b.z_min, b.z_max do
        if ((z - b.z_min) % 2) == 0 then
            crenel_at(b.x_min, z)
            crenel_at(b.x_max, z)
        end
    end

    -- ---------- 3. Tours aux 4 coins (5×5, jusqu'à tower_top) ----------
    for _, t in pairs(towers) do
        -- corps de la tour
        vm_fill_box(vm, area, data,
            { x = t.x_min, y = b.y_min,    z = t.z_min },
            { x = t.x_max, y = tower_top - 1, z = t.z_max }, c_tower)
        -- créneaux au sommet tour (couronne)
        local ty = tower_top
        for x = t.x_min, t.x_max do
            for z = t.z_min, t.z_max do
                local on_edge = (x == t.x_min or x == t.x_max or z == t.z_min or z == t.z_max)
                if on_edge and (((x + z) % 2) == 0) then
                    local idx = area:index(x, ty, z)
                    if idx then data[idx] = c_tower end
                end
            end
        end
        -- creuse intérieur tour (3×3 interior) du sol jusqu'à tower_top-2
        local ix0, ix1 = t.x_min + 1, t.x_max - 1
        local iz0, iz1 = t.z_min + 1, t.z_max - 1
        vm_fill_box(vm, area, data,
            { x = ix0, y = b.y_min, z = iz0 },
            { x = ix1, y = tower_top - 1, z = iz1 }, c_air)
        -- plancher au niveau du chemin de ronde (y = b.y_max + 1)
        vm_fill_box(vm, area, data,
            { x = ix0, y = b.y_max, z = iz0 },
            { x = ix1, y = b.y_max, z = iz1 }, c_tower)
    end

    -- ---------- 4. Trou pour échelle d'accès depuis tour SW ----------
    -- L'échelle monte dans la tour SW, sort par un trou dans le plancher de ronde
    local lp = tgw_map.get_ladder_pos()
    local hole_idx = area:index(lp.x, tgw_map.WALL_BASE_Y + tgw_map.WALL_HEIGHT - 1, lp.z)
    -- (sera percé après pose, voir étape 5)

    vm:set_data(data)
    vm:write_to_map(true)

    -- ---------- 5. Meta HP par node (VoxelManip n'appelle pas on_construct) ----------
    -- Mur
    for z = b.z_min, b.z_max do
        for y = b.y_min, b.y_max do
            for x = b.x_min, b.x_max do
                local n = core.get_node({ x = x, y = y, z = z }).name
                if n == "tgw_wall:stone" then
                    core.get_meta({ x = x, y = y, z = z }):set_int("hp", NODE_HP)
                elseif n == "tgw_wall:tower" then
                    core.get_meta({ x = x, y = y, z = z }):set_int("hp", NODE_HP * 2)
                end
            end
        end
    end

    -- ---------- 6. Escaliers en spirale dans LES 4 tours ----------
    -- Chaque tour : interior 3×3, spirale antihoraire de 7 marches
    -- (SW → S → SE → E → NE → N → NW), une marche par niveau y=b.y_min..b.y_min+6.
    -- param2 facedir stairs : 0=+Z, 1=+X, 2=-Z, 3=-X
    local stair = "stairs:stair_stone"
    if not core.registered_nodes[stair] then
        stair = "tgw_wall:stone"  -- fallback
    end
    local function build_tower_stairs(t)
        local ix0, ix1 = t.x_min + 1, t.x_max - 1
        local iz0, iz1 = t.z_min + 1, t.z_max - 1
        local steps = {
            { x = ix0,     y = b.y_min,     z = iz0,     p2 = 0 },
            { x = ix0 + 1, y = b.y_min + 1, z = iz0,     p2 = 1 },
            { x = ix1,     y = b.y_min + 2, z = iz0,     p2 = 0 },
            { x = ix1,     y = b.y_min + 3, z = iz0 + 1, p2 = 0 },
            { x = ix1,     y = b.y_min + 4, z = iz1,     p2 = 3 },
            { x = ix0 + 1, y = b.y_min + 5, z = iz1,     p2 = 3 },
            { x = ix0,     y = b.y_min + 6, z = iz1,     p2 = 2 },
        }
        for _, s in ipairs(steps) do
            core.set_node({ x = s.x, y = s.y, z = s.z }, { name = stair, param2 = s.p2 })
        end
        -- Trou dans plancher de ronde au-dessus de la dernière marche (NW)
        core.set_node({ x = ix0,     y = tgw_map.WALL_TOP_Y, z = iz1 }, { name = "air" })
        core.set_node({ x = ix0 + 1, y = tgw_map.WALL_TOP_Y, z = iz1 }, { name = "air" })
    end
    for _, t in pairs(towers) do
        build_tower_stairs(t)
    end

    storage:set_int("built", 1)
    core.log("action", "[tgw_wall] built enceinte 150×150 thick=" .. thick ..
        " + 4 tours + échelle SW")
end

-- ---------------------------------------------------------------------------
-- Damage / repair
-- ---------------------------------------------------------------------------

local function is_wall_node(name)
    return name == "tgw_wall:stone" or name == "tgw_wall:tower"
end

function tgw_wall.get_hp(pos)
    local node = core.get_node(pos)
    if not is_wall_node(node.name) then return 0 end
    return core.get_meta(pos):get_int("hp")
end

function tgw_wall.damage(pos, amount)
    local node = core.get_node(pos)
    if not is_wall_node(node.name) then return end
    local meta = core.get_meta(pos)
    local hp   = meta:get_int("hp") - amount
    if hp <= 0 then
        core.remove_node(pos)
        tgw_core.emit("wall_damaged", { pos = pos, hp_left = 0, destroyed = true })
    else
        meta:set_int("hp", hp)
        tgw_core.emit("wall_damaged", { pos = pos, hp_left = hp, destroyed = false })
    end
end

function tgw_wall.repair(pos, amount)
    local node = core.get_node(pos)
    if node.name == "air" then
        core.set_node(pos, { name = "tgw_wall:stone" })
        core.get_meta(pos):set_int("hp", math.min(NODE_HP, amount or NODE_HP))
        return
    end
    if not is_wall_node(node.name) then return end
    local meta = core.get_meta(pos)
    local cap  = (node.name == "tgw_wall:tower") and (NODE_HP * 2) or NODE_HP
    local hp   = math.min(cap, meta:get_int("hp") + (amount or NODE_HP))
    meta:set_int("hp", hp)
end

-- ---------------------------------------------------------------------------
-- Auto-build au premier joueur
-- ---------------------------------------------------------------------------

core.register_on_joinplayer(function(player)
    if not wall_built() then
        core.after(1.0, function() tgw_wall.build() end)
    end
end)

tgw_core.on("world_reset", function()
    storage:set_int("built", 0)
end)

core.log("action", "[tgw_wall] loaded")
