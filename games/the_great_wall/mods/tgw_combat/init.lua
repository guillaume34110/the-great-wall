-- tgw_combat : framework armes + 3 armes pilote (bat melee, pistol hitscan,
-- shotgun multi-ray spread). Munitions infinies (ammo arrive bloc 8).
-- Accessoires : champs prêts dans def, exploitation bloc 8.

local S = core.get_translator("tgw_combat")
tgw_combat = {}
tgw_combat.S = S

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------

        max_drop_level = 1,
tgw_combat.weapons = {}  -- id -> def

-- def schema :
--   id            string                 ("pistol")
--   label         string                 (display name)
--   tier          int                    1..5 (drop rarity, bloc 7)
--   type          "melee"|"hitscan"|"shotgun"
--   damage        int                    base damage per hit/pellet
--   cooldown      float                  s between shots
--   range         float                  blocks (hitscan only; melee = reach)
--   pellets       int                    shotgun nb rays
--   spread_deg    float                  shotgun cone half-angle
--   color         "#RRGGBB"              placeholder tint
--   accessory_slots table                 future : { barrel=true, mag=true, ... }

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function play_sfx(user)
    core.sound_play("default_tool_breaks", { pos = user:get_pos(), gain = 0.3, max_hear_distance = 20 }, true)
end

local function spawn_tracer(p1, p2)
    -- ligne courte de particules entre départ et impact
    local d = vector.subtract(p2, p1)
    local len = vector.length(d)
    if len < 0.1 then return end
    local n = math.min(20, math.floor(len * 2))
    local step = vector.divide(d, n)
    for i = 1, n do
        local pos = vector.add(p1, vector.multiply(step, i))
        core.add_particle({
            pos = pos,
            velocity = { x = 0, y = 0, z = 0 },
            expirationtime = 0.15,
            size = 1.2,
            texture = "default_steel_block.png^[colorize:#ffee66:255",
            glow = 12,
        })
    end
end

local function check_cooldown(itemstack, cd_s)
    local meta = itemstack:get_meta()
    local now  = core.get_us_time() / 1e6
    local last = tonumber(meta:get_string("last_use")) or 0
    if now - last < cd_s then return false end
    meta:set_string("last_use", tostring(now))
    return true
end

local function eye_pos(player)
    local pos = player:get_pos()
    pos.y = pos.y + (player:get_properties().eye_height or 1.625)
    return pos
end

-- direction +/- spread cone aléatoire
local function jitter_dir(dir, spread_deg)
    if not spread_deg or spread_deg <= 0 then return dir end
    local rad = math.rad(spread_deg)
    local yaw   = (math.random() - 0.5) * 2 * rad
    local pitch = (math.random() - 0.5) * 2 * rad
    -- petite approximation : rotation locale autour des axes monde Y et X
    local cy, sy = math.cos(yaw), math.sin(yaw)
    local cp, sp = math.cos(pitch), math.sin(pitch)
    local x = dir.x * cy - dir.z * sy
    local z = dir.x * sy + dir.z * cy
    local y = dir.y * cp - z * sp
    z = dir.y * sp + z * cp
    return vector.normalize({ x = x, y = y, z = z })
end

-- Raycast 1 rayon, applique dmg au premier hit, retourne point impact
local function fire_ray(user, dir, weapon)
    local start = eye_pos(user)
    local ende  = vector.add(start, vector.multiply(dir, weapon.range or 40))
    local ray   = core.raycast(start, ende, true, false)
    for pt in ray do
        if pt.type == "object" then
            local obj = pt.ref
            if obj and obj ~= user then
                obj:punch(user, 1.0, {
                    full_punch_interval = 1.0,
                    damage_groups = { fleshy = weapon.damage },
                }, dir)
                spawn_tracer(start, pt.intersection_point)
                return
            end
        elseif pt.type == "node" then
            local n = core.get_node(pt.under).name
            if n ~= "air" and n ~= "ignore" then
                -- mur tgw_wall:stone → dégâts au mur via hit player ? Non, on bloque juste.
                spawn_tracer(start, pt.intersection_point)
                return
            end
        end
    end
    spawn_tracer(start, ende)
end

-- ---------------------------------------------------------------------------
-- on_use dispatchers par type
-- ---------------------------------------------------------------------------

local function on_use_hitscan(weapon)
    return function(itemstack, user)
        if not user or not user:is_player() then return itemstack end
        if not check_cooldown(itemstack, weapon.cooldown) then return itemstack end
        fire_ray(user, user:get_look_dir(), weapon)
        play_sfx(user)
        return itemstack
    end
end

local function on_use_shotgun(weapon)
    return function(itemstack, user)
        if not user or not user:is_player() then return itemstack end
        if not check_cooldown(itemstack, weapon.cooldown) then return itemstack end
        local base = user:get_look_dir()
        for _ = 1, (weapon.pellets or 6) do
            fire_ray(user, jitter_dir(base, weapon.spread_deg or 5), weapon)
        end
        play_sfx(user)
        return itemstack
    end
end

-- ---------------------------------------------------------------------------
-- register_weapon
-- ---------------------------------------------------------------------------

function tgw_combat.register_weapon(def)
    assert(def.id and def.type and def.damage, "tgw_combat.register_weapon: id/type/damage requis")
    tgw_combat.weapons[def.id] = def
    local item_name = "tgw_combat:" .. def.id

    local tool = {
        description     = S(def.label or def.id),
        inventory_image = def.inventory_image or
            ("default_tool_steelsword.png^[colorize:" .. (def.color or "#888888") .. ":140"),
        stack_max       = 1,
        groups          = { tgw_weapon = 1, tgw_tier = def.tier or 1 },
        sound           = { breaks = "default_tool_breaks" },
    }

    if def.type == "melee" then
        tool.tool_capabilities = {
            full_punch_interval = def.cooldown or 0.6,
            max_drop_level      = 1,
            groupcaps           = {},
            damage_groups       = { fleshy = def.damage },
        }
        tool.range = def.range or 4
    else
        -- ranged : pas de punch (range=0), tout passe par on_use
        tool.range = 0
        tool.tool_capabilities = {
            full_punch_interval = def.cooldown or 0.5,
            max_drop_level      = 1,
            groupcaps           = {},
            damage_groups       = {},
        }
        if def.type == "hitscan" then
            tool.on_use = on_use_hitscan(def)
        elseif def.type == "shotgun" then
            tool.on_use = on_use_shotgun(def)
        else
            error("tgw_combat: type inconnu " .. tostring(def.type))
        end
    end

    core.register_tool(item_name, tool)
end

-- ---------------------------------------------------------------------------
-- Pilot weapons
-- ---------------------------------------------------------------------------

tgw_combat.register_weapon({
    id              = "bat",
    label           = "Patriot Bat",
    tier            = 1,
    type            = "melee",
    damage          = 15,
    cooldown        = 0.6,
    range           = 4,
    inventory_image = "tgw_combat_bat.png",
})

tgw_combat.register_weapon({
    id              = "pistol",
    label           = "9mm Pistol",
    tier            = 2,
    type            = "hitscan",
    damage          = 10,
    cooldown        = 0.45,
    range           = 35,
    inventory_image = "tgw_combat_pistol.png",
})

tgw_combat.register_weapon({
    id              = "shotgun",
    label           = "Border Shotgun",
    tier            = 2,
    type            = "shotgun",
    damage          = 5,
    cooldown        = 0.95,
    range           = 20,
    pellets         = 8,
    spread_deg      = 6,
    inventory_image = "tgw_combat_shotgun.png",
})

-- ---------------------------------------------------------------------------
-- Concombre starter : nourriture (heal 4 PV), pas une arme
-- ---------------------------------------------------------------------------

core.register_craftitem("tgw_combat:cucumber", {
    description = S("Border Cucumber"),
    inventory_image = "default_apple.png^[colorize:#338833:180",
    on_use = core.item_eat(4),
})

-- ---------------------------------------------------------------------------
-- Loadout starter
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
    player:get_inventory():set_list("main", {})
    core.after(tgw_core.config.respawn_cooldown, function()
        if player and player:is_player() then give_loadout(player) end
    end)
    return false
end)

core.log("action", "[tgw_combat] loaded (framework + " ..
    #({ "bat", "pistol", "shotgun" }) .. " weapons)")
