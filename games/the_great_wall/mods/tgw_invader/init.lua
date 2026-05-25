-- tgw_invader : entités ennemies (runner/tank/digger). AI custom : marche
-- vers la porte (Z négatif), attaque mur ou porte sur contact.
-- API : tgw_invader.spawn(type_name, pos) → entity

local S = core.get_translator("tgw_invader")
tgw_invader = {}
tgw_invader.S = S

-- ---------------------------------------------------------------------------
-- Stats par type
-- ---------------------------------------------------------------------------

tgw_invader.TYPES = {
    runner = {
        hp        = 20,
        speed     = 3.2,
        damage    = 5,          -- dégâts contre la porte par hit
        wall_dmg  = 2,
        attack_cd = 1.0,
        color     = "#3399ff",  -- bleu (rapide)
        visual_size = { x = 0.95, y = 0.95 },
    },
    tank = {
        hp        = 80,
        speed     = 1.4,
        damage    = 8,
        wall_dmg  = 10,
        attack_cd = 1.5,
        color     = "#aa3333",  -- rouge (gros)
        visual_size = { x = 1.15, y = 1.15 },
    },
    digger = {
        hp        = 40,
        speed     = 2.0,
        damage    = 4,
        wall_dmg  = 15,         -- spécialiste mur
        attack_cd = 1.0,
        color     = "#cc9933",  -- orange (creuseur)
        visual_size = { x = 1.0, y = 1.0 },
    },
    -- Ranged. Apparaissent wave ≥ 100. Stoppent à range, tirent au joueur.
    shooter = {
        hp           = 35,
        speed        = 1.8,
        damage       = 4,       -- contact porte (fallback)
        wall_dmg     = 2,
        attack_cd    = 1.5,
        attack_kind  = "ranged",
        ranged_dmg   = 6,
        ranged_range = 18,
        tracer_color = "#ff5544",
        color        = "#882288",
        visual_size  = { x = 1.0, y = 1.0 },
    },
    sniper = {
        hp           = 25,
        speed        = 1.2,
        damage       = 4,
        wall_dmg     = 1,
        attack_cd    = 3.0,
        attack_kind  = "ranged",
        ranged_dmg   = 15,
        ranged_range = 50,
        tracer_color = "#ff2222",
        color        = "#553388",
        visual_size  = { x = 1.05, y = 1.05 },
    },
    -- Boss : wave % 10 == 0, wave ≥ 100. Rotation cyclique.
    boss_titan = {
        hp            = 1000,
        speed         = 1.0,
        damage        = 30,
        wall_dmg      = 60,
        attack_cd     = 1.2,
        color         = "#aa0000",
        visual_size   = { x = 2.4, y = 2.4 },
        is_boss       = true,
        boss_label    = "Titan of the Border",
        reward_shared = 500,
    },
    boss_gunner = {
        hp            = 700,
        speed         = 1.6,
        damage        = 5,
        wall_dmg      = 4,
        attack_cd     = 0.7,
        attack_kind   = "ranged",
        ranged_dmg    = 22,
        ranged_range  = 35,
        tracer_color  = "#ff00aa",
        color         = "#770077",
        visual_size   = { x = 2.0, y = 2.0 },
        is_boss       = true,
        boss_label    = "Warlord Gunner",
        reward_shared = 500,
    },
    boss_summoner = {
        hp            = 600,
        speed         = 1.1,
        damage        = 10,
        wall_dmg      = 6,
        attack_cd     = 2.0,
        color         = "#cc44cc",
        visual_size   = { x = 2.1, y = 2.1 },
        is_boss       = true,
        boss_label    = "Necro Coyote",
        reward_shared = 700,
        summon_cd     = 8.0,
        summon_type   = "runner",
        summon_count  = 3,
    },
}

local BOSS_ROTATION = { "boss_titan", "boss_gunner", "boss_summoner" }
function tgw_invader.boss_for_wave(wave_idx)
    if wave_idx < 100 or wave_idx % 10 ~= 0 then return nil end
    local k = ((wave_idx / 10) - 10) % #BOSS_ROTATION + 1
    return BOSS_ROTATION[k]
end
function tgw_invader.boss_scale(wave_idx)
    -- 1.0 à wave 100 → 4.0 à wave 200
    return 1.0 + math.max(0, (wave_idx - 100)) / 33
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function get_target_pos()
    local d = tgw_map.get_door_pos()
    return { x = d.x, y = d.y, z = d.z }
end

local function dist2d(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return math.sqrt(dx*dx + dz*dz)
end

local function node_at(pos)
    return core.get_node(pos)
end

local function is_obstacle(node)
    if not node or node.name == "ignore" or node.name == "air" then return false end
    local def = core.registered_nodes[node.name]
    if not def then return false end
    return def.walkable == true
end

-- ---------------------------------------------------------------------------
-- Ranged helpers
-- ---------------------------------------------------------------------------

local function head_pos(obj)
    local p = obj:get_pos()
    return { x = p.x, y = p.y + 1.3, z = p.z }
end

local function has_los(from, to_player)
    local pp = to_player:get_pos()
    local target = { x = pp.x, y = pp.y + 1.3, z = pp.z }
    local ray = core.raycast(from, target, true, false)
    for pt in ray do
        if pt.type == "object" then
            if pt.ref == to_player then return true end
        elseif pt.type == "node" then
            local n = core.get_node(pt.under).name
            if n ~= "air" and n ~= "ignore" then
                local d = core.registered_nodes[n]
                if d and d.walkable then return false end
            end
        end
    end
    return false
end

local function nearest_player_in_range(from, max_range)
    local best, best_d2 = nil, max_range * max_range
    for _, p in ipairs(core.get_connected_players()) do
        if p:get_hp() > 0 then
            local pp = p:get_pos()
            local dx, dy, dz = pp.x - from.x, pp.y - from.y, pp.z - from.z
            local d2 = dx*dx + dy*dy + dz*dz
            if d2 < best_d2 and has_los(from, p) then
                best, best_d2 = p, d2
            end
        end
    end
    return best
end

local function spawn_enemy_tracer(p1, p2, color)
    local d = vector.subtract(p2, p1)
    local len = vector.length(d)
    if len < 0.1 then return end
    local n = math.min(24, math.floor(len * 2))
    local step = vector.divide(d, n)
    for i = 1, n do
        local pos = vector.add(p1, vector.multiply(step, i))
        core.add_particle({
            pos = pos,
            velocity = { x = 0, y = 0, z = 0 },
            expirationtime = 0.18,
            size = 1.2,
            texture = "default_steel_block.png^[colorize:" ..
                (color or "#ff5544") .. ":255",
            glow = 12,
        })
    end
end

local function ranged_shoot(self, target_player)
    local from = head_pos(self.object)
    local pp   = target_player:get_pos()
    local to   = { x = pp.x, y = pp.y + 1.3, z = pp.z }
    spawn_enemy_tracer(from, to, self._tgw_stats.tracer_color)
    target_player:punch(self.object, 1.0, {
        full_punch_interval = 1.0,
        damage_groups = { fleshy = self._tgw_stats.ranged_dmg or 5 },
    }, vector.normalize(vector.subtract(to, from)))
    core.sound_play("default_tool_breaks",
        { pos = from, gain = 0.25, max_hear_distance = 24 }, true)
end

-- ---------------------------------------------------------------------------
-- Entity factory
-- ---------------------------------------------------------------------------

local function make_entity_def(type_name, stats)
    return {
        initial_properties = {
            visual         = "mesh",
            mesh           = "character.b3d",
            textures       = { "character.png^[colorize:" .. stats.color .. ":150" },
            visual_size    = stats.visual_size,
            collisionbox   = { -0.3, 0.0, -0.3, 0.3, 1.7, 0.3 },
            physical       = true,
            stepheight     = 1.1,
            hp_max         = stats.hp,
            makes_footstep_sound = false,
            automatic_face_movement_dir = 90.0,
        },

        _tgw_type      = type_name,
        _tgw_stats     = stats,
        _attack_timer  = 0,
        _step_acc      = 0,

        on_activate = function(self, staticdata)
            self.object:set_armor_groups({ fleshy = 100 })
            self.object:set_hp(stats.hp)
            -- staticdata : "wave_idx|hp" — sérialisé sur unload
            if staticdata and staticdata ~= "" then
                local wave, hp = staticdata:match("(%d+)|(%d+)")
                if hp then self.object:set_hp(tonumber(hp)) end
                if wave then self._wave_idx = tonumber(wave) end
            end
        end,

        get_staticdata = function(self)
            return (self._wave_idx or 0) .. "|" .. self.object:get_hp()
        end,

        on_step = function(self, dtime)
            self._step_acc = self._step_acc + dtime
            if self._step_acc < 0.2 then return end
            local dt = self._step_acc
            self._step_acc = 0
            local stats = self._tgw_stats or stats

            self._attack_timer = math.max(0, self._attack_timer - dt)

            -- Boss summoner : invoque minions périodiquement.
            if stats.summon_cd then
                self._summon_timer = (self._summon_timer or stats.summon_cd) - dt
                if self._summon_timer <= 0 then
                    self._summon_timer = stats.summon_cd
                    local p = self.object:get_pos()
                    local n = stats.summon_count or 3
                    for i = 1, n do
                        local a = (i / n) * math.pi * 2
                        local sp = {
                            x = p.x + math.cos(a) * 2.0,
                            y = p.y,
                            z = p.z + math.sin(a) * 2.0,
                        }
                        tgw_invader.spawn(stats.summon_type or "runner",
                            sp, self._wave_idx)
                        tgw_core.emit("invader_returned", {})
                    end
                    core.add_particlespawner({
                        amount = 40, time = 0.3,
                        minpos = vector.subtract(p, {x=1.5,y=0,z=1.5}),
                        maxpos = vector.add(p,      {x=1.5,y=2,z=1.5}),
                        minvel = { x = -1, y = 2, z = -1 },
                        maxvel = { x =  1, y = 4, z =  1 },
                        minexptime = 0.6, maxexptime = 1.2,
                        minsize = 1.5, maxsize = 3.0,
                        texture = "default_mese_crystal_fragment.png^[colorize:#cc44cc:200",
                        glow = 14,
                    })
                end
            end

            local pos = self.object:get_pos()
            if not pos then return end

            -- Ranged : si joueur en LOS dans range, on stoppe et on tire.
            if stats.attack_kind == "ranged" then
                local from   = head_pos(self.object)
                local target_p = nearest_player_in_range(from, stats.ranged_range or 18)
                if target_p then
                    -- yaw face cible
                    local pp = target_p:get_pos()
                    self.object:set_yaw(
                        math.atan2(pp.z - pos.z, pp.x - pos.x) + math.pi / 2)
                    local v = self.object:get_velocity()
                    self.object:set_velocity({ x = 0, y = v.y, z = 0 })
                    if self._attack_timer == 0 then
                        ranged_shoot(self, target_p)
                        self._attack_timer = stats.attack_cd
                    end
                    return
                end
                -- Sinon, comportement marche-vers-porte ci-dessous.
            end

            local target = get_target_pos()

            -- Atteint la porte ?
            local d = dist2d(pos, target)
            if d < 2.0 then
                tgw_core.emit("invader_reached_house", { invader = self })
                if self._attack_timer == 0 then
                    tgw_house.damage_door(stats.damage)
                    self._attack_timer = stats.attack_cd
                end
                self.object:set_velocity({ x = 0, y = self.object:get_velocity().y, z = 0 })
                return
            end

            -- Direction vers la cible (X,Z)
            local dx = target.x - pos.x
            local dz = target.z - pos.z
            local len = math.sqrt(dx*dx + dz*dz)
            if len < 0.001 then return end
            dx, dz = dx/len, dz/len

            -- Check node devant (à hauteur torse)
            local ahead = { x = pos.x + dx * 0.8, y = pos.y + 0.5, z = pos.z + dz * 0.8 }
            local front_node = node_at(ahead)

            if is_obstacle(front_node) then
                -- Mur du jeu ? on tape (stone ou tour)
                if front_node.name == "tgw_wall:stone" or front_node.name == "tgw_wall:tower" then
                    if self._attack_timer == 0 then
                        local wall_pos = vector.round(ahead)
                        tgw_wall.damage(wall_pos, stats.wall_dmg)
                        self._attack_timer = stats.attack_cd
                    end
                    self.object:set_velocity({ x = 0, y = self.object:get_velocity().y, z = 0 })
                    return
                end
                -- Autre obstacle : tente de sauter
                local v = self.object:get_velocity()
                if v.y < 0.1 then
                    self.object:set_velocity({ x = dx * stats.speed * 0.5, y = 5, z = dz * stats.speed * 0.5 })
                end
                return
            end

            -- Marche normale
            local v = self.object:get_velocity()
            self.object:set_velocity({ x = dx * stats.speed, y = v.y, z = dz * stats.speed })
            self.object:set_yaw(math.atan2(dz, dx) + math.pi / 2)
        end,

        on_punch = function(self, puncher, time_from_last_punch, tool_caps, dir, damage)
            local stats = self._tgw_stats or stats
            local hp = self.object:get_hp() - (damage or 0)
            if hp <= 0 then
                if stats.is_boss then
                    local pos = self.object:get_pos() or { x=0, y=0, z=0 }
                    core.chat_send_all(core.colorize("#ff4444",
                        "[BOSS] " .. (stats.boss_label or type_name) ..
                        " " .. S("has fallen!")))
                    if tgw_economy and tgw_economy.add_shared then
                        tgw_economy.add_shared(stats.reward_shared or 300)
                    end
                    tgw_core.emit("boss_killed",
                        { type = type_name, killer = puncher })
                    core.add_particlespawner({
                        amount = 120, time = 0.5,
                        minpos = vector.subtract(pos, {x=1.5,y=0,z=1.5}),
                        maxpos = vector.add(pos,      {x=1.5,y=2.5,z=1.5}),
                        minvel = { x = -3, y = 1, z = -3 },
                        maxvel = { x =  3, y = 5, z =  3 },
                        minexptime = 0.8, maxexptime = 1.8,
                        minsize = 2.0, maxsize = 4.5,
                        texture = "default_gold_lump.png",
                        glow = 14,
                    })
                    core.sound_play("default_tnt_explode",
                        { pos = pos, gain = 1.2, max_hear_distance = 64 }, true)
                end
                tgw_core.emit("invader_killed", { invader = self, killer = puncher })
                self.object:remove()
                return
            end
            self.object:set_hp(hp)
        end,
    }
end

for type_name, stats in pairs(tgw_invader.TYPES) do
    core.register_entity("tgw_invader:" .. type_name, make_entity_def(type_name, stats))
end

-- ---------------------------------------------------------------------------
-- Spawn API
-- ---------------------------------------------------------------------------

function tgw_invader.spawn(type_name, pos, wave_idx)
    local stats = tgw_invader.TYPES[type_name]
    if not stats then
        core.log("error", "[tgw_invader] unknown type: " .. tostring(type_name))
        return nil
    end
    local obj = core.add_entity(pos, "tgw_invader:" .. type_name)
    if obj and obj:get_luaentity() then
        local le = obj:get_luaentity()
        le._wave_idx = wave_idx or 1
        -- Boss : scale HP/damage selon wave.
        if stats.is_boss then
            local mult = tgw_invader.boss_scale(wave_idx or 100)
            local new_hp = math.floor(stats.hp * mult)
            obj:set_properties({ hp_max = new_hp })
            obj:set_hp(new_hp)
            -- Stats overrides instance-locales (sans toucher la table partagée)
            le._tgw_stats = setmetatable({
                damage     = math.floor(stats.damage * mult),
                wall_dmg   = math.floor(stats.wall_dmg * mult),
                ranged_dmg = stats.ranged_dmg and math.floor(stats.ranged_dmg * mult) or nil,
            }, { __index = stats })
        end
    end
    return obj
end

do
    local names = {}
    for n in pairs(tgw_invader.TYPES) do table.insert(names, n) end
    table.sort(names)
    core.log("action", "[tgw_invader] loaded (" ..
        table.concat(names, ", ") .. ")")
end
