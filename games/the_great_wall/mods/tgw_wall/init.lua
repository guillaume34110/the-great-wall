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

-- Loot crate : casino payant. Cost personnel, spin animé, arme aléatoire.
local GACHA_COST = 60
local LOOT_POOL = {
    "tgw_combat:ar",
    "tgw_combat:sniper",
    "tgw_combat:shotgun",
    "tgw_combat:minigun",
    "tgw_capture:net",
    "tgw_combat:pistol",
}

local gacha_busy = {}  -- name -> true pendant l'anim (anti spam)

local function gacha_frame(name, pos, prize, i, steps)
    if not gacha_busy[name] then return end
    local item = (i < steps) and LOOT_POOL[math.random(1, #LOOT_POOL)] or prize
    local fs = "formspec_version[6]size[7,7]" ..
        "bgcolor[#101015FA;true]" ..
        "label[2.2,0.6;" .. core.formspec_escape(S("LOOT CASINO")) .. "]" ..
        "box[0.6,1.2;5.8,4;#1c1c24]" ..
        "item_image[2.5,1.7;2,2;" .. item .. "]"
    if i < steps then
        fs = fs .. "label[2.5,4.4;" .. core.formspec_escape(S("Spinning…")) .. "]"
        core.show_formspec(name, "tgw_wall:gacha", fs)
        local t       = i / steps
        local delay   = 0.06 + (t * t) * 0.30  -- easing : accélère en quadratique
        core.after(delay, gacha_frame, name, pos, prize, i + 1, steps)
    else
        local label = core.registered_items[prize]
            and core.registered_items[prize].description or prize
        fs = fs .. "label[1.6,4.4;" ..
            core.formspec_escape(S("You won: @1!", label)) .. "]" ..
            "button_exit[2.5,5.5;2,0.8;ok;OK]"
        core.show_formspec(name, "tgw_wall:gacha", fs)
        local p = core.get_player_by_name(name)
        if p then p:get_inventory():add_item("main", prize) end
        if core.get_node(pos).name == "tgw_wall:loot_crate" then
            core.set_node(pos, { name = "tgw_wall:loot_crate_empty" })
        end
        gacha_busy[name] = nil
    end
end

core.register_node("tgw_wall:loot_crate", {
    description = S("Loot Casino (@1$)", GACHA_COST),
    tiles = {
        "default_chest_top.png^[colorize:#dd9933:90",
        "default_chest_top.png^[colorize:#dd9933:90",
        "default_chest_side.png^[colorize:#dd9933:90",
        "default_chest_side.png^[colorize:#dd9933:90",
        "default_chest_side.png^[colorize:#dd9933:90",
        "default_chest_front.png^[colorize:#dd9933:90",
    },
    paramtype  = "light",
    light_source = 6,
    groups     = { tgw_loot = 1, not_in_creative_inventory = 1 },
    drop       = "",
    can_dig    = function() return false end,
    on_blast   = function() end,
    on_rightclick = function(pos, node, clicker)
        if not (clicker and clicker:is_player()) then return end
        local name = clicker:get_player_name()
        if gacha_busy[name] then return end
        if not tgw_economy.pay_personal(name, GACHA_COST) then
            core.chat_send_player(name,
                S("Need @1$ personal to roll.", GACHA_COST))
            return
        end
        gacha_busy[name] = true
        local prize = LOOT_POOL[math.random(1, #LOOT_POOL)]
        gacha_frame(name, pos, prize, 1, 16)
    end,
})

core.register_node("tgw_wall:loot_crate_empty", {
    description = S("Empty Crate"),
    tiles = {
        "default_chest_top.png^[colorize:#444444:120",
        "default_chest_top.png^[colorize:#444444:120",
        "default_chest_side.png^[colorize:#444444:120",
        "default_chest_side.png^[colorize:#444444:120",
        "default_chest_side.png^[colorize:#444444:120",
        "default_chest_inside.png^[colorize:#222222:140",
    },
    paramtype  = "light",
    groups     = { tgw_loot = 1, not_in_creative_inventory = 1 },
    drop       = "",
    can_dig    = function() return false end,
    on_blast   = function() end,
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

    -- Bounding total : englobe tours + couronne crénelée
    local p1 = { x = b.x_min, y = b.y_min,        z = b.z_min }
    local p2 = { x = b.x_max, y = tower_top + 2, z = b.z_max }

    local vm = core.get_voxel_manip()
    local emin, emax = vm:read_from_map(p1, p2)
    local area = VoxelArea:new{ MinEdge = emin, MaxEdge = emax }
    local data = vm:get_data()

    -- ---------- 0. Clear total : arbres/décorations dans toute la zone ----------
    -- Tout ce qui dépasse le sol (y >= b.y_min) dans la bbox enceinte → air.
    -- Évite les forêts denses qui apparaîtraient au-dessus du ground.
    vm_fill_box(vm, area, data,
        { x = b.x_min, y = b.y_min, z = b.z_min },
        { x = b.x_max, y = tower_top + 5, z = b.z_max }, c_air)

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

    -- ---------- 3. Tours aux 4 coins (9×9, toit solide à tower_top) ----------
    -- Structure : périmètre + toit pleins (y=b.y_min..tower_top), intérieur creusé
    -- jusqu'à tower_top-1 (shaft pour spirale), couronne crénelée à tower_top+1.
    for _, t in pairs(towers) do
        local ix0, ix1 = t.x_min + 1, t.x_max - 1
        local iz0, iz1 = t.z_min + 1, t.z_max - 1
        -- corps plein (perimetre + toit)
        vm_fill_box(vm, area, data,
            { x = t.x_min, y = b.y_min, z = t.z_min },
            { x = t.x_max, y = tower_top, z = t.z_max }, c_tower)
        -- creuse intérieur (laisse toit à tower_top intact)
        vm_fill_box(vm, area, data,
            { x = ix0, y = b.y_min, z = iz0 },
            { x = ix1, y = tower_top - 1, z = iz1 }, c_air)
        -- couronne crénelée au sommet (y = tower_top + 1, perimetre alterné)
        local cy = tower_top + 1
        for x = t.x_min, t.x_max do
            for z = t.z_min, t.z_max do
                local on_edge = (x == t.x_min or x == t.x_max or z == t.z_min or z == t.z_max)
                if on_edge and (((x + z) % 2) == 0) then
                    local idx = area:index(x, cy, z)
                    if idx then data[idx] = c_tower end
                end
            end
        end

        -- Bandes wall-walk : la tour mange une partie du chemin de ronde.
        -- On repose un plancher au niveau b.y_max dans l'intersection wall-band
        -- × intérieur tour, pour que le walkway continue à travers la tour.
        local thick = b.thick
        local at_s = (t.z_min == b.z_min)
        local at_n = (t.z_max == b.z_max)
        local at_w = (t.x_min == b.x_min)
        local at_e = (t.x_max == b.x_max)
        if at_s then
            vm_fill_box(vm, area, data,
                { x = ix0, y = b.y_max, z = iz0 },
                { x = ix1, y = b.y_max, z = math.min(iz1, b.z_min + thick - 1) }, c_tower)
        end
        if at_n then
            vm_fill_box(vm, area, data,
                { x = ix0, y = b.y_max, z = math.max(iz0, b.z_max - thick + 1) },
                { x = ix1, y = b.y_max, z = iz1 }, c_tower)
        end
        if at_w then
            vm_fill_box(vm, area, data,
                { x = ix0, y = b.y_max, z = iz0 },
                { x = math.min(ix1, b.x_min + thick - 1), y = b.y_max, z = iz1 }, c_tower)
        end
        if at_e then
            vm_fill_box(vm, area, data,
                { x = math.max(ix0, b.x_max - thick + 1), y = b.y_max, z = iz0 },
                { x = ix1, y = b.y_max, z = iz1 }, c_tower)
        end

        -- Entrée sol (y=b.y_min..b.y_min+1) face intérieure (vers centre enceinte)
        local inner_face_z = at_s and t.z_max or t.z_min
        local entry_x      = math.floor((t.x_min + t.x_max) / 2)
        for y = b.y_min, b.y_min + 1 do
            local idx = area:index(entry_x, y, inner_face_z)
            if idx then data[idx] = c_air end
        end

        -- Ouvertures niveau chemin de ronde (y=b.y_max+1..+2) pour traverser la
        -- tour depuis le walkway voisin. Face opposée au coin extérieur.
        if at_s then
            local fx = at_w and t.x_max or t.x_min
            for y = b.y_max + 1, b.y_max + 2 do
                for z = b.z_min, b.z_min + thick - 1 do
                    local idx = area:index(fx, y, z)
                    if idx then data[idx] = c_air end
                end
            end
        end
        if at_n then
            local fx = at_w and t.x_max or t.x_min
            for y = b.y_max + 1, b.y_max + 2 do
                for z = b.z_max - thick + 1, b.z_max do
                    local idx = area:index(fx, y, z)
                    if idx then data[idx] = c_air end
                end
            end
        end
        if at_w then
            local fz = at_s and t.z_max or t.z_min
            for y = b.y_max + 1, b.y_max + 2 do
                for x = b.x_min, b.x_min + thick - 1 do
                    local idx = area:index(x, y, fz)
                    if idx then data[idx] = c_air end
                end
            end
        end
        if at_e then
            local fz = at_s and t.z_max or t.z_min
            for y = b.y_max + 1, b.y_max + 2 do
                for x = b.x_max - thick + 1, b.x_max do
                    local idx = area:index(x, y, fz)
                    if idx then data[idx] = c_air end
                end
            end
        end
    end

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

    -- ---------- 6. Escaliers droits le long des 4 murs intérieurs ----------
    -- 7 marches par escalier, climbing parallèle au mur, contre face intérieure.
    -- param2 facedir stairs : 0=+Z (climb +Z), 1=+X, 2=-Z, 3=-X
    local stair = "stairs:stair_stone"
    if not core.registered_nodes[stair] then
        stair = "tgw_wall:stone"  -- fallback
    end
    -- Un escalier par mur, départ au centre du mur, climbing direction définie.
    -- Inner face : à `thick` blocs du bord extérieur.
    local runs = {
        -- mur sud : inner face z = b.z_min+thick, climb +X depuis x=-3
        { x0 = -3,                  z0 = b.z_min + thick, dx = 1, dz = 0, p2 = 1 },
        -- mur nord : inner face z = b.z_max-thick, climb -X depuis x=3
        { x0 = 3,                   z0 = b.z_max - thick, dx = -1, dz = 0, p2 = 3 },
        -- mur ouest : inner face x = b.x_min+thick, climb +Z depuis z=-3
        { x0 = b.x_min + thick,     z0 = -3,              dx = 0, dz = 1, p2 = 0 },
        -- mur est : inner face x = b.x_max-thick, climb -Z depuis z=3
        { x0 = b.x_max - thick,     z0 = 3,               dx = 0, dz = -1, p2 = 2 },
    }
    -- 8 marches y=b.y_min..b.y_min+7 (=9..16). Dernière marche au niveau du
    -- haut de mur, surface = y+0.5 → step de 0.5 jusqu'au sommet (y=17).
    for _, r in ipairs(runs) do
        for i = 0, 7 do
            local p = {
                x = r.x0 + r.dx * i,
                y = b.y_min + i,
                z = r.z0 + r.dz * i,
            }
            core.set_node(p, { name = stair, param2 = r.p2 })
        end
    end

    -- ---------- 7. Spirale dans chaque tour : 18 marches, 3 segments × 6 ----------
    -- y=b.y_min..tower_top (9..26). p2 facedir : 0=+Z, 1=+X, 2=-Z, 3=-X.
    -- Pose marches + tunnel 3-cubes au-dessus (clearance tête, perce les slabs).
    for _, t in pairs(towers) do
        local ix0, ix1 = t.x_min + 1, t.x_max - 1
        local iz0, iz1 = t.z_min + 1, t.z_max - 1
        local tower_runs = {
            { x0 = ix0, z0 = iz0, dx = 1,  dz = 0, p2 = 1, n = 6 },  -- sud, +X
            { x0 = ix1, z0 = iz0, dx = 0,  dz = 1, p2 = 0, n = 6 },  -- est, +Z
            { x0 = ix1, z0 = iz1, dx = -1, dz = 0, p2 = 3, n = 6 },  -- nord, -X
        }
        local y = b.y_min
        for _, r in ipairs(tower_runs) do
            for i = 0, r.n - 1 do
                local sx = r.x0 + r.dx * i
                local sz = r.z0 + r.dz * i
                core.set_node({ x = sx, y = y, z = sz }, { name = stair, param2 = r.p2 })
                -- tunnel 3 cubes au-dessus (la marche elle-même + 3 = 4 cubes)
                for dy = 1, 3 do
                    local p = { x = sx, y = y + dy, z = sz }
                    if core.get_node(p).name ~= "air" then
                        core.remove_node(p)
                    end
                end
                y = y + 1
            end
        end
    end

    -- ---------- 8. Torches murales sur face intérieure du rempart ----------
    -- default:torch_wall, paramtype2=wallmounted.
    -- param2 wallmounted : 2=-X wall, 3=+X wall, 4=-Z wall, 5=+Z wall
    -- Hauteur 3 cubes au-dessus du sol (y = b.y_min + 3 = 12).
    local torch_wall = "default:torch_wall"
    if core.registered_nodes[torch_wall] then
        local ty   = b.y_min + 3
        local step = 16
        -- Air-cell juste à l'intérieur du mur (premier cube hors épaisseur)
        local az_s = b.z_min + thick     -- air, mur au sud (-Z)
        local az_n = b.z_max - thick     -- air, mur au nord (+Z)
        local ax_w = b.x_min + thick     -- air, mur à l'ouest (-X)
        local ax_e = b.x_max - thick     -- air, mur à l'est  (+X)

        -- Sud / Nord
        for x = b.x_min + 12, b.x_max - 12, step do
            core.set_node({ x = x, y = ty, z = az_s }, { name = torch_wall, param2 = 4 })
            core.set_node({ x = x, y = ty, z = az_n }, { name = torch_wall, param2 = 5 })
        end
        -- Ouest / Est
        for z = b.z_min + 12, b.z_max - 12, step do
            core.set_node({ x = ax_w, y = ty, z = z }, { name = torch_wall, param2 = 2 })
            core.set_node({ x = ax_e, y = ty, z = z }, { name = torch_wall, param2 = 3 })
        end

        -- 1 torche par tour, sur la face ouest intérieure (libre de la spirale)
        for _, t in pairs(towers) do
            local cz = math.floor((t.z_min + t.z_max) / 2)
            local tx = t.x_min + 1   -- air cell collé au mur ouest (-X)
            core.set_node({ x = tx, y = ty, z = cz }, { name = torch_wall, param2 = 2 })
        end
    end

    storage:set_int("built", 1)
    core.log("action", "[tgw_wall] built enceinte 150×150 thick=" .. thick ..
        " + 4 tours + échelle SW + torches")
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
