-- tgw_combat : framework armes + 3 armes pilote (bat melee, pistol hitscan,
-- shotgun multi-ray spread). Munitions infinies (ammo arrive bloc 8).
-- Accessoires : champs prêts dans def, exploitation bloc 8.

local S = core.get_translator("tgw_combat")
tgw_combat = {}
tgw_combat.S = S

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- XP / Level system (per-itemstack via meta)
-- ---------------------------------------------------------------------------
local MAX_LVL    = 10
local XP_PER_KILL = 10  -- base ; sniper/minigun loot tier ne change pas le gain

local function xp_needed(lvl)
    -- 50, ~152, ~292, ~466, ~673, ~911, ~1180, ~1478, ~1806, ~2162
    return math.floor(50 * (lvl ^ 1.6))
end

local function level_for(xp)
    local lvl = 0
    while lvl < MAX_LVL and xp >= xp_needed(lvl + 1) do
        lvl = lvl + 1
    end
    return lvl
end

local function scaled_stats(def, lvl)
    return {
        damage     = math.floor(def.damage * (1 + 0.10 * lvl) + 0.5),
        cooldown   = def.cooldown * math.max(0.5, 1 - 0.04 * lvl),
        range      = def.range,
        spread_deg = def.spread_deg,
        mag_size   = def.mag_size,
        pellets    = def.pellets,
        reload_mul = 1.0,
    }
end

-- Slots accessoires standardisés.
local ACC_SLOTS = { "barrel", "mag", "sight", "grip" }

local function apply_accessories(s, itemstack)
    if not tgw_combat.accessories then return s end
    local meta = itemstack:get_meta()
    for _, slot in ipairs(ACC_SLOTS) do
        local id  = meta:get_string("acc_" .. slot)
        local acc = id ~= "" and tgw_combat.accessories[id]
        if acc and acc.effects then
            local e = acc.effects
            if e.damage_mul   then s.damage   = math.floor(s.damage * e.damage_mul + 0.5) end
            if e.cooldown_mul then s.cooldown = s.cooldown * e.cooldown_mul end
            if e.range_mul    and s.range      then s.range      = s.range * e.range_mul end
            if e.spread_mul   and s.spread_deg then s.spread_deg = s.spread_deg * e.spread_mul end
            if e.mag_mul      and s.mag_size   then s.mag_size   = math.floor(s.mag_size * e.mag_mul + 0.5) end
            if e.reload_mul   then s.reload_mul = s.reload_mul * e.reload_mul end
        end
    end
    return s
end

local function effective(def, itemstack)
    local lvl = level_for(itemstack:get_meta():get_int("xp"))
    local s   = apply_accessories(scaled_stats(def, lvl), itemstack)
    return s, lvl
end
tgw_combat._effective = effective  -- export pour debug

local function refresh_stack(itemstack, def)
    local meta = itemstack:get_meta()
    local xp   = meta:get_int("xp")
    local lvl  = level_for(xp)
    local s    = apply_accessories(scaled_stats(def, lvl), itemstack)
    local next_xp = (lvl < MAX_LVL) and xp_needed(lvl + 1) or xp
    local pct  = (lvl < MAX_LVL)
        and math.floor(100 * xp / next_xp) or 100
    local ammo_line = ""
    if s.mag_size then
        if not meta:contains("ammo") then
            meta:set_int("ammo", s.mag_size)
        end
        local now      = core.get_us_time() / 1e6
        local rl_until = tonumber(meta:get_string("reload_until")) or 0
        if rl_until > now then
            ammo_line = "\n" .. core.colorize("#ff8844",
                "Reloading… " .. string.format("%.1fs", rl_until - now))
        else
            ammo_line = "\n" .. core.colorize("#88ccff",
                "Ammo " .. meta:get_int("ammo") .. "/" .. s.mag_size)
        end
    end
    local acc_line = ""
    if tgw_combat.accessories then
        local parts = {}
        for _, slot in ipairs(ACC_SLOTS) do
            local id = meta:get_string("acc_" .. slot)
            if id ~= "" and tgw_combat.accessories[id] then
                table.insert(parts, tgw_combat.accessories[id].label)
            end
        end
        if #parts > 0 then
            acc_line = "\n" .. core.colorize("#cc88ff",
                "[" .. table.concat(parts, ", ") .. "]")
        end
    end
    local desc = S(def.label or def.id) ..
        "\n" .. core.colorize("#ffcc44", "Lv " .. lvl) ..
        "  " .. core.colorize("#888888",
            xp .. "/" .. next_xp .. " XP  (" .. pct .. "%)") ..
        "\n" .. core.colorize("#aaaaaa",
            "DMG " .. s.damage .. "  CD " ..
            string.format("%.2fs", s.cooldown)) ..
        ammo_line .. acc_line
    meta:set_string("description", desc)
    -- Melee : tool_capabilities mutables via meta (override l'enregistrement).
    if def.type == "melee" then
        meta:set_tool_capabilities({
            full_punch_interval = s.cooldown,
            max_drop_level      = 1,
            groupcaps           = {},
            damage_groups       = { fleshy = s.damage },
        })
    end
    return lvl, s
end
tgw_combat._refresh_stack = refresh_stack

-- Ajoute XP à la première stack matching dans l'inventaire main du joueur.
function tgw_combat.add_xp(player, weapon_id, amount)
    if not player or not player:is_player() then return end
    local def = tgw_combat.weapons[weapon_id]
    if not def then return end
    local inv  = player:get_inventory()
    local list = inv:get_list("main")
    for i, st in ipairs(list) do
        if st:get_name() == "tgw_combat:" .. weapon_id then
            local meta = st:get_meta()
            local old  = level_for(meta:get_int("xp"))
            meta:set_int("xp", meta:get_int("xp") + amount)
            local new = refresh_stack(st, def)
            inv:set_stack("main", i, st)
            if new > old then
                local pname = player:get_player_name()
                core.chat_send_player(pname, core.colorize("#ffcc44",
                    "[XP] " .. S(def.label) .. " → Lv " .. new))
                core.sound_play("default_dig_metal",
                    { object = player, gain = 0.6, max_hear_distance = 16 }, true)
                -- Mini-burst particles autour du joueur
                local pos = player:get_pos()
                core.add_particlespawner({
                    amount = 25, time = 0.5,
                    minpos = vector.subtract(pos, {x=0.4,y=0.4,z=0.4}),
                    maxpos = vector.add(pos,      {x=0.4,y=1.4,z=0.4}),
                    minvel = { x = -0.5, y = 1, z = -0.5 },
                    maxvel = { x =  0.5, y = 2, z =  0.5 },
                    minexptime = 0.6, maxexptime = 1.0,
                    minsize = 1.0, maxsize = 2.0,
                    texture = "default_gold_lump.png",
                    glow = 14,
                })
            end
            return new
        end
    end
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
-- Ammo / Reload (per-itemstack)
-- ---------------------------------------------------------------------------
-- État : meta.ammo (int) + meta.reload_until (epoch s). Reload gratuit.
-- Cycle : on_use → vérifie reload terminé → si oui refill mag → tire (mag-1).
-- Si mag tombe à 0 → start reload (durée = 3 × cooldown effectif).
-- Pendant reload : on_use refuse (chat info).

local function check_reload(itemstack, def, s_eff)
    if not s_eff.mag_size then return "ok" end
    local meta = itemstack:get_meta()
    local now  = core.get_us_time() / 1e6
    local rl_until = tonumber(meta:get_string("reload_until")) or 0
    if rl_until > 0 then
        if now >= rl_until then
            meta:set_int("ammo", s_eff.mag_size)
            meta:set_string("reload_until", "")
            return "refilled"
        end
        return "busy", rl_until - now
    end
    if not meta:contains("ammo") then
        meta:set_int("ammo", s_eff.mag_size)
    end
    return "ok"
end

local function start_reload(itemstack, def, s_eff, user)
    local meta = itemstack:get_meta()
    local now  = core.get_us_time() / 1e6
    local dur  = s_eff.cooldown * 3 * (s_eff.reload_mul or 1.0)
    meta:set_string("reload_until", tostring(now + dur))
    core.sound_play("default_dig_metal",
        { object = user, gain = 0.4, max_hear_distance = 16 }, true)
    core.chat_send_player(user:get_player_name(),
        core.colorize("#ff8844", "[Reload] " .. S(def.label) ..
            " " .. string.format("%.1fs", dur)))
end

-- ---------------------------------------------------------------------------
-- on_use dispatchers par type
-- ---------------------------------------------------------------------------

local function consume_ammo_or_block(itemstack, weapon, user, s_eff)
    if not s_eff.mag_size then return true end
    local state, remain = check_reload(itemstack, weapon, s_eff)
    if state == "busy" then
        core.chat_send_player(user:get_player_name(),
            core.colorize("#888888", "[Reload] " ..
                string.format("%.1fs", remain)))
        return false
    end
    local meta = itemstack:get_meta()
    local ammo = meta:get_int("ammo")
    if ammo <= 0 then
        start_reload(itemstack, weapon, s_eff, user)
        refresh_stack(itemstack, weapon)
        return false
    end
    meta:set_int("ammo", ammo - 1)
    if ammo - 1 <= 0 then
        start_reload(itemstack, weapon, s_eff, user)
    end
    refresh_stack(itemstack, weapon)
    return true
end

local function on_use_hitscan(weapon)
    return function(itemstack, user)
        if not user or not user:is_player() then return itemstack end
        local s = effective(weapon, itemstack)
        if not check_cooldown(itemstack, s.cooldown) then return itemstack end
        if not consume_ammo_or_block(itemstack, weapon, user, s) then
            return itemstack
        end
        fire_ray(user, user:get_look_dir(),
            { damage = s.damage, range = s.range })
        play_sfx(user)
        return itemstack
    end
end

local function on_use_shotgun(weapon)
    return function(itemstack, user)
        if not user or not user:is_player() then return itemstack end
        local s = effective(weapon, itemstack)
        if not check_cooldown(itemstack, s.cooldown) then return itemstack end
        if not consume_ammo_or_block(itemstack, weapon, user, s) then
            return itemstack
        end
        local base = user:get_look_dir()
        for _ = 1, (s.pellets or 6) do
            fire_ray(user,
                jitter_dir(base, s.spread_deg or 5),
                { damage = s.damage, range = s.range })
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
    mag_size        = 12,
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
    mag_size        = 6,
    inventory_image = "tgw_combat_shotgun.png",
})

-- Tier 3+ : armes haut de gamme (shop cher + loot mural)
tgw_combat.register_weapon({
    id              = "ar",
    label           = "Eagle AR-15",
    tier            = 3,
    type            = "hitscan",
    damage          = 18,
    cooldown        = 0.25,
    range           = 40,
    mag_size        = 30,
    inventory_image = "tgw_combat_ar.png",
})

tgw_combat.register_weapon({
    id              = "sniper",
    label           = "Lone Star Sniper",
    tier            = 3,
    type            = "hitscan",
    damage          = 60,
    cooldown        = 1.4,
    range           = 80,
    mag_size        = 5,
    inventory_image = "tgw_combat_sniper.png",
})

tgw_combat.register_weapon({
    id              = "minigun",
    label           = "Freedom Minigun",
    tier            = 4,
    type            = "hitscan",
    damage          = 12,
    cooldown        = 0.10,
    range           = 35,
    mag_size        = 100,
    inventory_image = "tgw_combat_minigun.png",
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
    tgw_combat.init_stack_display(player)
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

-- ---------------------------------------------------------------------------
-- XP gain : hook sur invader_killed
-- ---------------------------------------------------------------------------
tgw_core.on("invader_killed", function(p)
    local k = p.killer
    if not (k and k.is_player and k:is_player()) then return end
    local stack = k:get_wielded_item()
    local name  = stack:get_name()
    local wid   = name:match("^tgw_combat:(.+)$")
    if not wid or not tgw_combat.weapons[wid] then return end
    tgw_combat.add_xp(k, wid, XP_PER_KILL)
end)

-- ---------------------------------------------------------------------------
-- Initialise display sur stacks neuves (loadout + pickup Mystery Box)
-- ---------------------------------------------------------------------------
function tgw_combat.init_stack_display(player)
    if not player or not player:is_player() then return end
    local inv  = player:get_inventory()
    local list = inv:get_list("main")
    local now  = core.get_us_time() / 1e6
    for i, st in ipairs(list) do
        local wid = st:get_name():match("^tgw_combat:(.+)$")
        local def = wid and tgw_combat.weapons[wid]
        if def then
            local meta     = st:get_meta()
            local needs    = meta:get_string("description") == ""
            local rl_until = tonumber(meta:get_string("reload_until")) or 0
            if needs or rl_until > 0 then
                if rl_until > 0 and now >= rl_until then
                    meta:set_int("ammo", def.mag_size)
                    meta:set_string("reload_until", "")
                end
                refresh_stack(st, def)
                inv:set_stack("main", i, st)
            end
        end
    end
end

-- Tick par joueur (1s) : rafraîchit countdown reload + pickup loot/Mystery Box.
local function tick_init()
    for _, p in ipairs(core.get_connected_players()) do
        tgw_combat.init_stack_display(p)
    end
    core.after(1.0, tick_init)
end
core.after(2.0, tick_init)

-- ---------------------------------------------------------------------------
-- Accessoires (4 slots : barrel / mag / sight / grip)
-- ---------------------------------------------------------------------------
tgw_combat.accessories = {}

function tgw_combat.register_accessory(def)
    assert(def.id and def.slot and def.label, "accessory needs id/slot/label")
    tgw_combat.accessories[def.id] = def
    core.register_craftitem("tgw_combat:acc_" .. def.id, {
        description     = S(def.label) ..
            "\n" .. core.colorize("#888888", "[" .. def.slot .. "]") ..
            (def.blurb and ("\n" .. core.colorize("#aaaaaa", def.blurb)) or ""),
        inventory_image = def.inventory_image or
            ("default_steel_ingot.png^[colorize:" ..
             (def.color or "#cc88ff") .. ":180"),
        stack_max       = 1,
        groups          = { tgw_accessory = 1, tgw_tier = def.tier or 2 },
    })
end

-- Pool initial : 2 par slot.
tgw_combat.register_accessory({
    id = "ext_barrel", slot = "barrel", label = "Extended Barrel",
    blurb = "+30% range, +10% damage", tier = 2, color = "#7799ff",
    effects = { range_mul = 1.30, damage_mul = 1.10 },
})
tgw_combat.register_accessory({
    id = "supp", slot = "barrel", label = "Suppressor",
    blurb = "-50% spread, -10% damage", tier = 3, color = "#444444",
    effects = { spread_mul = 0.50, damage_mul = 0.90 },
})
tgw_combat.register_accessory({
    id = "ext_mag", slot = "mag", label = "Extended Mag",
    blurb = "+50% magazine size", tier = 2, color = "#44cc44",
    effects = { mag_mul = 1.5 },
})
tgw_combat.register_accessory({
    id = "drum", slot = "mag", label = "Drum Mag",
    blurb = "+100% mag, +30% reload time", tier = 3, color = "#aacc22",
    effects = { mag_mul = 2.0, reload_mul = 1.30 },
})
tgw_combat.register_accessory({
    id = "red_dot", slot = "sight", label = "Red Dot Sight",
    blurb = "-40% spread", tier = 2, color = "#ff3333",
    effects = { spread_mul = 0.60 },
})
tgw_combat.register_accessory({
    id = "scope", slot = "sight", label = "Tactical Scope",
    blurb = "+20% damage, +50% range", tier = 3, color = "#222288",
    effects = { damage_mul = 1.20, range_mul = 1.50 },
})
tgw_combat.register_accessory({
    id = "foregrip", slot = "grip", label = "Foregrip",
    blurb = "-25% cooldown", tier = 2, color = "#cc8844",
    effects = { cooldown_mul = 0.75 },
})
tgw_combat.register_accessory({
    id = "tac_grip", slot = "grip", label = "Tactical Grip",
    blurb = "-30% reload time, -10% cooldown", tier = 3, color = "#dd44aa",
    effects = { reload_mul = 0.70, cooldown_mul = 0.90 },
})

-- ---------------------------------------------------------------------------
-- Formspec loadout
-- ---------------------------------------------------------------------------
local LOADOUT_FORM = "tgw_combat:loadout"
-- pname -> { weapon_id, inv_idx }
local loadout_session = {}

local function find_wielded_weapon(player)
    local ws = player:get_wielded_item()
    local wid = ws:get_name():match("^tgw_combat:(.+)$")
    if not wid or not tgw_combat.weapons[wid] then return nil end
    return wid, player:get_wield_index()
end

local function list_accessories_in_inv(player, slot)
    local out = {}
    for i, st in ipairs(player:get_inventory():get_list("main")) do
        local id = st:get_name():match("^tgw_combat:acc_(.+)$")
        local acc = id and tgw_combat.accessories[id]
        if acc and (not slot or acc.slot == slot) then
            table.insert(out, { idx = i, id = id, acc = acc })
        end
    end
    return out
end

local function build_loadout_fs(player)
    local pname = player:get_player_name()
    local sess  = loadout_session[pname]
    if not sess then return nil end
    local inv   = player:get_inventory()
    local ws    = inv:get_stack("main", sess.inv_idx)
    if ws:get_name() ~= "tgw_combat:" .. sess.weapon_id then return nil end
    local def   = tgw_combat.weapons[sess.weapon_id]
    local s     = effective(def, ws)
    local meta  = ws:get_meta()

    local W, H = 11, 10
    local fs = "formspec_version[6]size[" .. W .. "," .. H .. "]" ..
        "bgcolor[#101015F0;true]" ..
        "label[0.4,0.5;" .. core.formspec_escape(
            S(def.label) .. "  —  " .. S("Loadout")) .. "]" ..
        "label[0.4,1.0;" .. core.formspec_escape(
            "DMG " .. s.damage ..
            "   CD " .. string.format("%.2fs", s.cooldown) ..
            (s.range and ("   RNG " .. math.floor(s.range)) or "") ..
            (s.mag_size and ("   MAG " .. s.mag_size) or "")) .. "]"

    -- 4 slots (gauche)
    for i, slot in ipairs(ACC_SLOTS) do
        local y     = 1.6 + (i - 1) * 1.7
        local id    = meta:get_string("acc_" .. slot)
        local acc   = id ~= "" and tgw_combat.accessories[id]
        local label = acc and acc.label or S("(empty)")
        fs = fs ..
            "box[0.4," .. y .. ";5.0,1.5;#1c1c24]" ..
            "label[0.6," .. (y + 0.3) .. ";" ..
                core.formspec_escape(slot:upper()) .. "]" ..
            "label[0.6," .. (y + 0.8) .. ";" ..
                core.formspec_escape(label) .. "]"
        if acc then
            fs = fs ..
                "button[4.2," .. (y + 0.4) ..
                ";1.0,0.7;unequip_" .. slot .. ";X]"
        end
    end

    -- Accessoires dispo (droite)
    fs = fs ..
        "label[5.8,1.4;" .. core.formspec_escape(S("Available")) .. "]"
    local accs = list_accessories_in_inv(player)
    for i, e in ipairs(accs) do
        if i > 10 then break end
        local row = (i - 1) % 5
        local col = math.floor((i - 1) / 5)
        local x = 5.8 + col * 2.6
        local y = 1.8 + row * 1.4
        fs = fs ..
            "box[" .. x .. "," .. y .. ";2.4,1.2;#1c1c24]" ..
            "label[" .. (x + 0.1) .. "," .. (y + 0.3) .. ";" ..
                core.formspec_escape(e.acc.label) .. "]" ..
            "label[" .. (x + 0.1) .. "," .. (y + 0.7) .. ";" ..
                core.formspec_escape("[" .. e.acc.slot .. "]") .. "]" ..
            "button[" .. (x + 1.4) .. "," .. (y + 0.4) ..
                ";0.9,0.7;equip_" .. e.id .. ";+]"
    end

    fs = fs ..
        "button_exit[0.4," .. (H - 0.8) .. ";2.0,0.7;close;" ..
        core.formspec_escape(S("Close")) .. "]"
    return fs
end

function tgw_combat.show_loadout(player)
    local wid, idx = find_wielded_weapon(player)
    if not wid then
        core.chat_send_player(player:get_player_name(),
            core.colorize("#ff8844",
                "[Loadout] " .. S("Wield a weapon first.")))
        return
    end
    local pname = player:get_player_name()
    loadout_session[pname] = { weapon_id = wid, inv_idx = idx }
    local fs = build_loadout_fs(player)
    if fs then core.show_formspec(pname, LOADOUT_FORM, fs) end
end

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= LOADOUT_FORM then return end
    local pname = player:get_player_name()
    local sess  = loadout_session[pname]
    if not sess then return true end
    local inv   = player:get_inventory()
    local ws    = inv:get_stack("main", sess.inv_idx)
    if ws:get_name() ~= "tgw_combat:" .. sess.weapon_id then
        loadout_session[pname] = nil
        return true
    end
    local def  = tgw_combat.weapons[sess.weapon_id]
    local meta = ws:get_meta()
    local changed = false

    for _, slot in ipairs(ACC_SLOTS) do
        if fields["unequip_" .. slot] then
            local id = meta:get_string("acc_" .. slot)
            if id ~= "" then
                local leftover = inv:add_item("main",
                    ItemStack("tgw_combat:acc_" .. id))
                if not leftover:is_empty() then
                    -- inv plein : drop au sol
                    core.add_item(player:get_pos(), leftover)
                end
                meta:set_string("acc_" .. slot, "")
                changed = true
            end
        end
    end

    for id, acc in pairs(tgw_combat.accessories) do
        if fields["equip_" .. id] then
            -- vérifie présence dans inv
            local item_name = "tgw_combat:acc_" .. id
            if inv:contains_item("main", item_name) then
                -- swap éventuel
                local old_id = meta:get_string("acc_" .. acc.slot)
                if old_id ~= "" then
                    local leftover = inv:add_item("main",
                        ItemStack("tgw_combat:acc_" .. old_id))
                    if not leftover:is_empty() then
                        core.add_item(player:get_pos(), leftover)
                    end
                end
                inv:remove_item("main", ItemStack(item_name))
                meta:set_string("acc_" .. acc.slot, id)
                changed = true
            end
            break
        end
    end

    if changed then
        refresh_stack(ws, def)
        inv:set_stack("main", sess.inv_idx, ws)
        local fs = build_loadout_fs(player)
        if fs then core.show_formspec(pname, LOADOUT_FORM, fs) end
    end
    if fields.close or fields.quit then
        loadout_session[pname] = nil
    end
    return true
end)

-- Trigger : sneak + right-click ouvre le loadout.
-- on_secondary_use est invoqué sur shift+right-click ; on_place sinon.
-- Pour fiabilité on attache aux deux + chatcommand /loadout.
do
    local function attach_loadout_triggers()
        for id, _ in pairs(tgw_combat.weapons) do
            local item_name = "tgw_combat:" .. id
            local def = core.registered_items[item_name]
            if def then
                local orig_place = def.on_place
                core.override_item(item_name, {
                    on_secondary_use = function(_, user)
                        if user and user:is_player() then
                            tgw_combat.show_loadout(user)
                        end
                    end,
                    on_place = function(itemstack, user, pointed)
                        if user and user:is_player() then
                            tgw_combat.show_loadout(user)
                            return itemstack
                        end
                        if orig_place then
                            return orig_place(itemstack, user, pointed)
                        end
                    end,
                })
            end
        end
    end
    core.after(0, attach_loadout_triggers)
end

core.register_chatcommand("loadout", {
    description = "Open weapon loadout (equip accessories)",
    func = function(name)
        local p = core.get_player_by_name(name)
        if p then tgw_combat.show_loadout(p) end
        return true
    end,
})

do
    local wcount, acount = 0, 0
    for _ in pairs(tgw_combat.weapons)     do wcount = wcount + 1 end
    for _ in pairs(tgw_combat.accessories) do acount = acount + 1 end
    core.log("action", "[tgw_combat] loaded (framework + " ..
        wcount .. " weapons, " .. acount ..
        " accessories, XP + mag + accs)")
end
