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
}

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

            self._attack_timer = math.max(0, self._attack_timer - dt)

            local pos = self.object:get_pos()
            if not pos then return end
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
            local hp = self.object:get_hp() - (damage or 0)
            if hp <= 0 then
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
    if not tgw_invader.TYPES[type_name] then
        core.log("error", "[tgw_invader] unknown type: " .. tostring(type_name))
        return nil
    end
    local obj = core.add_entity(pos, "tgw_invader:" .. type_name)
    if obj and obj:get_luaentity() then
        obj:get_luaentity()._wave_idx = wave_idx or 1
    end
    return obj
end

core.log("action", "[tgw_invader] loaded (" ..
    (tgw_invader.TYPES.runner and "runner+" or "") ..
    (tgw_invader.TYPES.tank   and "tank+"   or "") ..
    (tgw_invader.TYPES.digger and "digger"  or "") .. ")")
