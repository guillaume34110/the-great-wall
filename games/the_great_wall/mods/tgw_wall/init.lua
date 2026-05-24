-- tgw_wall : mur 150 nodes, HP par node (meta), génération via VoxelManip.
-- API : tgw_wall.build(), tgw_wall.damage(pos, amount), tgw_wall.repair(pos, amount)

local S = core.get_translator("tgw_wall")
tgw_wall = {}
tgw_wall.S = S

local cfg     = tgw_core.config
local NODE_HP = cfg.wall_node_hp  -- 50
local storage = core.get_mod_storage()

-- ---------------------------------------------------------------------------
-- Node : tgw_wall:stone — texture default_stone_block, indestructible à la pioche
-- ---------------------------------------------------------------------------

core.register_node("tgw_wall:stone", {
    description = S("Great Wall Stone"),
    tiles = { "default_stone_block.png" },
    -- groups : pas de cracky → indigable par les outils standards.
    -- damage_per_second = 0 ; tout passe par tgw_wall.damage().
    groups = { tgw_wall = 1, not_in_creative_inventory = 1 },
    drop = "",
    sounds = default.node_sound_stone_defaults(),
    on_construct = function(pos)
        core.get_meta(pos):set_int("hp", NODE_HP)
    end,
    can_dig = function() return false end,
    on_blast = function() end,
})

-- ---------------------------------------------------------------------------
-- Génération : VoxelManip 150×6
-- ---------------------------------------------------------------------------

local function wall_built() return storage:get_int("built") == 1 end

function tgw_wall.build(force)
    if wall_built() and not force then return end

    local b      = tgw_map.get_wall_bounds()
    local c_wall = core.get_content_id("tgw_wall:stone")

    local p1 = { x = b.x_min, y = b.y_min, z = b.z }
    local p2 = { x = b.x_max, y = b.y_max, z = b.z }

    local vm = core.get_voxel_manip()
    local emin, emax = vm:read_from_map(p1, p2)
    local area = VoxelArea:new{ MinEdge = emin, MaxEdge = emax }
    local data = vm:get_data()

    for i in area:iterp(p1, p2) do data[i] = c_wall end
    vm:set_data(data)
    vm:write_to_map(true)

    -- on_construct n'est PAS appelé par VoxelManip → on set la meta nous-mêmes
    for x = b.x_min, b.x_max do
        for y = b.y_min, b.y_max do
            core.get_meta({ x = x, y = y, z = b.z }):set_int("hp", NODE_HP)
        end
    end

    storage:set_int("built", 1)
    core.log("action", "[tgw_wall] built " ..
        ((b.x_max - b.x_min + 1) * (b.y_max - b.y_min + 1)) .. " nodes")
end

-- ---------------------------------------------------------------------------
-- Damage / repair
-- ---------------------------------------------------------------------------

function tgw_wall.get_hp(pos)
    local node = core.get_node(pos)
    if node.name ~= "tgw_wall:stone" then return 0 end
    return core.get_meta(pos):get_int("hp")
end

function tgw_wall.damage(pos, amount)
    local node = core.get_node(pos)
    if node.name ~= "tgw_wall:stone" then return end
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
        -- reconstruire le node
        core.set_node(pos, { name = "tgw_wall:stone" })
        core.get_meta(pos):set_int("hp", math.min(NODE_HP, amount or NODE_HP))
        return
    end
    if node.name ~= "tgw_wall:stone" then return end
    local meta = core.get_meta(pos)
    local hp   = math.min(NODE_HP, meta:get_int("hp") + (amount or NODE_HP))
    meta:set_int("hp", hp)
end

-- ---------------------------------------------------------------------------
-- Auto-build au premier joueur qui join (mapgen flat → terrain prêt)
-- ---------------------------------------------------------------------------

core.register_on_joinplayer(function(player)
    if not wall_built() then
        core.after(1.0, function() tgw_wall.build() end)
    end
end)

-- Reset hook : tgw_reset déclenche "world_reset" avant wipe
tgw_core.on("world_reset", function()
    storage:set_int("built", 0)
end)

core.log("action", "[tgw_wall] loaded")
