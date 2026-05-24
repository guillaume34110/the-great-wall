-- Application persistante du choix : modèle, texture teintée, taille, freeze.

local R = lumia_chargen.races
local META_DONE     = "lumia_chargen_done"
local META_RACE     = "lumia_chargen_race"
local META_VARIANT  = "lumia_chargen_variant"
local META_CLASS    = "lumia_chargen_class"
local META_PNAME    = "lumia_chargen_charname"
local META_MAJOR    = "lumia_chargen_major"  -- json string
local META_MINOR    = "lumia_chargen_minor"
local META_SIGN     = "lumia_chargen_sign"
local META_SPEC     = "lumia_chargen_spec"

local FROZEN = {}  -- pname → true pendant chargen, physics 0

local function base_skin()
    -- 3d_armor remplace la texture si actif. On garde character.png comme base.
    return "character.png"
end

local function variant_texture(race, variant)
    local h, s, l = variant.hsl[1] or 0, variant.hsl[2] or 0, variant.hsl[3] or 0
    -- [hsl: applique HUE, SAT delta, LUM delta. Disponible Luanti ≥ 5.6.
    return string.format("%s^[hsl:%d:%d:%d", base_skin(), h, s, l)
end

local function apply_visuals(player, race, variant)
    local model = "3d_armor_character.b3d"
    if not player_api.registered_models[model] then
        model = "character.b3d"
    end
    if player_api.set_model then
        player_api.set_model(player, model)
    end
    local tex = variant_texture(race, variant)
    if player_api.set_textures then
        -- 3d_armor utilise index 1 comme texture composée. Si actif, set_skin.
        if armor and armor.set_player_armor then
            -- Forcer la skin de base via meta 3d_armor.
            local pmeta = player:get_meta()
            pmeta:set_string("3d_armor_inventory", pmeta:get_string("3d_armor_inventory") or "")
            -- 3d_armor recalcule la composition au load. On set juste la texture brute,
            -- 3d_armor l'écrasera ; pour la persister on pose aussi via player_api.
        end
        player_api.set_textures(player, {tex})
    end
    local s = race.size or 1.0
    player:set_properties({visual_size = {x = s, y = s}})
end

local function apply_physics(player)
    -- physics par défaut, lumia_rpg ajustera ensuite par set_physics_override.
    player:set_physics_override({speed = 1.0, jump = 1.0, gravity = 1.0})
end

function lumia_chargen.is_done(name)
    local p = minetest.get_player_by_name(name)
    if not p then return false end
    return p:get_meta():get_int(META_DONE) == 1
end

function lumia_chargen.get_choice(name)
    local p = minetest.get_player_by_name(name)
    if not p then return nil end
    local meta = p:get_meta()
    if meta:get_int(META_DONE) ~= 1 then return nil end
    local major_raw = meta:get_string(META_MAJOR)
    local minor_raw = meta:get_string(META_MINOR)
    local major = (major_raw ~= "" and minetest.deserialize(major_raw)) or {}
    local minor = (minor_raw ~= "" and minetest.deserialize(minor_raw)) or {}
    return {
        race = meta:get_string(META_RACE),
        variant = meta:get_string(META_VARIANT),
        class = meta:get_string(META_CLASS),
        charname = meta:get_string(META_PNAME),
        sign = meta:get_string(META_SIGN),
        spec = meta:get_string(META_SPEC),
        major = major,
        minor = minor,
    }
end

function lumia_chargen.freeze(player)
    local pname = player:get_player_name()
    FROZEN[pname] = true
    player:set_physics_override({speed = 0, jump = 0, gravity = 1})
end

function lumia_chargen.unfreeze(player)
    local pname = player:get_player_name()
    FROZEN[pname] = nil
    player:set_physics_override({speed = 1.0, jump = 1.0, gravity = 1.0})
end

function lumia_chargen.is_frozen(name)
    return FROZEN[name] == true
end

function lumia_chargen.finalize(player, race, variant, class, charname, major, minor, sign, spec)
    local meta = player:get_meta()
    meta:set_int(META_DONE, 1)
    meta:set_string(META_RACE, race.id)
    meta:set_string(META_VARIANT, variant.id)
    meta:set_string(META_CLASS, class.id)
    meta:set_string(META_PNAME, charname or "")
    meta:set_string(META_MAJOR, minetest.serialize(major or {}))
    meta:set_string(META_MINOR, minetest.serialize(minor or {}))
    meta:set_string(META_SIGN, (sign and sign.id) or "")
    meta:set_string(META_SPEC, spec or class.spec or "combat")
    apply_visuals(player, race, variant)
    apply_physics(player)
    lumia_chargen.unfreeze(player)
    -- Callbacks (lumia_rpg accroche l'init des attrs/skills ici).
    for _, fn in ipairs(lumia_chargen._done_callbacks) do
        local ok, err = pcall(fn, player, {
            race = race.id, variant = variant.id, class = class.id,
            charname = charname, major = major, minor = minor,
            sign = (sign and sign.id) or nil,
            spec = spec or class.spec or "combat",
        })
        if not ok then lumia_chargen.log("error", "on_done cb: " .. tostring(err)) end
    end
    minetest.chat_send_player(player:get_player_name(), minetest.colorize("#88ddff",
        "[Lumia] Personnage créé : " .. (charname or player:get_player_name())
        .. " — " .. race.name .. " " .. variant.name .. " (" .. class.name .. ")"
        .. (sign and (" sous " .. sign.name) or "")))
end

-- Re-apply visuals on join for already-created players.
minetest.register_on_joinplayer(function(player)
    local meta = player:get_meta()
    if meta:get_int(META_DONE) ~= 1 then return end
    local race = R.find_race(meta:get_string(META_RACE))
    if not race then return end
    local variant = R.find_variant(race, meta:get_string(META_VARIANT))
    if not variant then variant = race.variants[1] end
    apply_visuals(player, race, variant)
end)

-- Admin : reset chargen (pour debug ou changement perso).
minetest.register_chatcommand("chargen_reset", {
    description = "Reset chargen pour un joueur (admin)",
    params = "<pname>",
    privs = {server = true},
    func = function(_, target)
        local p = minetest.get_player_by_name(target)
        if not p then return false, "joueur hors-ligne" end
        local meta = p:get_meta()
        for _, k in ipairs({META_DONE, META_RACE, META_VARIANT, META_CLASS,
                            META_PNAME, META_MAJOR, META_MINOR, META_SIGN, META_SPEC}) do
            meta:set_string(k, "")
        end
        return true, "chargen reset pour " .. target .. " (re-trigger au prochain join)"
    end,
})
