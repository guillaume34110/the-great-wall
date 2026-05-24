_G.fmod = rawget(_G, "fmod") or {}
local fmod = _G.fmod

local function split_flags(value)
    local out = {}
    for item in tostring(value):gmatch("[^,%s]+") do
        table.insert(out, item)
    end
    return out
end

local DEFAULT_SETTINGS = {
    invsaw = {
        creative_priv = "creative",
        priv = "interact",
        saw_item = "stairsplus:circular_saw",
    },
    moreblocks = {
        outline_trap_nodes = true,
    },
    stairs = {
        legacy_stairs_without_recipeitem = false,
    },
    stairsplus = {
        circular_saw_crafting = true,
        ex_nihilo = minetest.settings:get_bool("creative_mode", false),
        in_creative_inventory = true,
        in_craft_guide = true,
        default_align_style = "user",
        basic_shapes = {
            "micro_8", "slab_8", "stair", "stair_inner", "stair_outer",
            "panel_1", "panel_2", "panel_4", "panel_8", "panel_12", "panel_14", "panel_15",
            "slope", "slope_half", "slope_half_raised", "slope_inner", "slope_inner_cut",
            "slope_inner_half", "slope_inner_half_raised", "slope_inner_cut_half",
            "slope_inner_cut_half_raised", "slope_outer", "slope_outer_cut",
            "slope_outer_half", "slope_outer_half_raised", "slope_outer_cut_half",
            "slope_outer_cut_half_raised", "slope_cut", "slab_1", "slab_2", "slab_4",
            "slab_12", "slab_14", "slab_15", "slab_two_sides", "slab_three_sides",
            "slab_three_sides_u", "micro_1", "micro_2", "micro_4", "micro_12",
            "micro_14", "micro_15", "stair_half", "stair_right_half",
            "stair_alt_1", "stair_alt_2", "stair_alt_4", "stair_alt_8",
        },
        common_shapes = {
            "micro_8", "panel_8", "slab_1", "slab_8", "stair",
            "stair_inner", "stair_outer", "slope", "slope_half", "slope_half_raised",
            "slope_inner", "slope_inner_cut", "slope_inner_half", "slope_inner_cut_half",
            "slope_inner_half_raised", "slope_inner_cut_half_raised", "slope_outer",
            "slope_outer_cut", "slope_cut", "slope_outer_half", "slope_outer_cut_half",
            "slope_outer_half_raised", "slope_outer_cut_half_raised",
        },
        legacy_mode = true,
        legacy_place_mechanic = true,
        crafting_schemata_enabled = true,
        whitelist_mode = false,
        silence_group_overrides = false,
    },
    stairsplus_legacy = {
        basic_materials = true,
        default = true,
        farming = true,
        gloopblocks = true,
        technic = true,
        prefab = true,
        wool = true,
    },
}

local function get_setting(modname, key, default)
    local namespaced = modname .. "." .. key
    local raw = minetest.settings:get(namespaced)
    if raw == nil then
        return default
    end
    if type(default) == "boolean" then
        return minetest.settings:get_bool(namespaced, default)
    end
    if type(default) == "table" then
        return split_flags(raw)
    end
    return raw
end

function fmod.check_version()
    return true
end

function fmod.create(name)
    local modname = name or minetest.get_current_modname()
    local modpath = minetest.get_modpath(modname)
    local defaults = DEFAULT_SETTINGS[modname] or {}
    local settings = {}
    for key, default in pairs(defaults) do
        settings[key] = get_setting(modname, key, default)
    end

    local has = setmetatable({}, {
        __index = function(_, dep)
            return minetest.get_modpath(dep) ~= nil
        end,
    })

    local module = {
        name = modname,
        modname = modname,
        path = modpath,
        modpath = modpath,
        settings = settings,
        has = has,
        S = minetest.get_translator(modname),
        storage = minetest.get_mod_storage and minetest.get_mod_storage() or nil,
    }

    function module.dofile(...)
        local parts = {...}
        local relpath = table.concat(parts, "/")
        return dofile(modpath .. "/" .. relpath .. ".lua")
    end

    function module.log(level, fmt, ...)
        local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
        minetest.log(level, "[" .. modname .. "] " .. msg)
    end

    return module
end
