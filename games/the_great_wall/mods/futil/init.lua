_G.futil = rawget(_G, "futil") or {}
local futil = _G.futil

local function resolve_alias(name)
    local seen = {}
    local current = name
    while minetest.registered_aliases and minetest.registered_aliases[current] and not seen[current] do
        seen[current] = true
        current = minetest.registered_aliases[current]
    end
    return current
end

futil.table = futil.table or {}

function futil.table.set_all(target, source)
    for key, value in pairs(source or {}) do
        target[key] = value
    end
    return target
end

function futil.table.is_empty(value)
    return next(value or {}) == nil
end

function futil.table.sort_keys(value)
    local keys = {}
    for key in pairs(value or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

function futil.check_version()
    return true
end

function futil.path_concat(...)
    local parts = {...}
    return table.concat(parts, "/")
end

function futil.load_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

function futil.write_file(path, content)
    local file = io.open(path, "wb")
    if not file then
        return false
    end
    file:write(content or "")
    file:close()
    return true
end

function futil.is_player(value)
    return value and value.is_player and value:is_player() or false
end

function futil.resolve_item(item)
    if type(item) ~= "string" then
        return item
    end
    return resolve_alias(item)
end

function futil.resolve_itemstack(itemstack)
    local stack = ItemStack(itemstack)
    stack:set_name(resolve_alias(stack:get_name()))
    return stack
end

function futil.get_location_string(ref)
    if ref and ref.get_location then
        local loc = ref:get_location()
        if type(loc) == "table" then
            if loc.type == "player" then
                return "current_player"
            end
            if loc.type == "nodemeta" and loc.pos then
                return "nodemeta:" .. minetest.pos_to_string(loc.pos)
            end
            if loc.type == "detached" and loc.name then
                return "detached:" .. loc.name
            end
        end
    end
    return "current_player"
end
