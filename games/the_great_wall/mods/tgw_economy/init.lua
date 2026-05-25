-- tgw_economy : dual-wallet (perso + commun).
-- Perso : player_meta. Commun : mod_storage (un seul int).

local S = core.get_translator("tgw_economy")
tgw_economy = {}
tgw_economy.S = S

local cfg     = tgw_core.config
local storage = core.get_mod_storage()
local KEY_SHARED = "shared"
local KEY_PERS   = "tgw_pers_$"  -- préfixe meta joueur
local ADMIN_INF  = 999999        -- crédits affichés pour admin (server priv)

local function is_admin(name)
    return name and core.check_player_privs(name, { server = true })
end

-- ---------------------------------------------------------------------------
-- Wallets
-- ---------------------------------------------------------------------------

function tgw_economy.get_shared()
    -- Si un admin est connecté, le wallet commun est infini aussi.
    for _, p in ipairs(core.get_connected_players()) do
        if is_admin(p:get_player_name()) then return ADMIN_INF end
    end
    return storage:get_int(KEY_SHARED)
end

function tgw_economy.add_shared(amount)
    local v = storage:get_int(KEY_SHARED) + amount
    if v < 0 then v = 0 end
    storage:set_int(KEY_SHARED, v)
    tgw_core.emit("wallet_changed", { kind = "shared", value = v })
    return v
end

function tgw_economy.pay_shared(amount)
    -- Admin connecté → gratuit, pas de débit.
    for _, p in ipairs(core.get_connected_players()) do
        if is_admin(p:get_player_name()) then return true end
    end
    local v = storage:get_int(KEY_SHARED)
    if v < amount then return false end
    storage:set_int(KEY_SHARED, v - amount)
    tgw_core.emit("wallet_changed", { kind = "shared", value = v - amount })
    return true
end

function tgw_economy.get_personal(player_name)
    if is_admin(player_name) then return ADMIN_INF end
    local p = core.get_player_by_name(player_name)
    if not p then return 0 end
    return p:get_meta():get_int(KEY_PERS)
end

function tgw_economy.add_personal(player_name, amount)
    if is_admin(player_name) then return ADMIN_INF end
    local p = core.get_player_by_name(player_name)
    if not p then return 0 end
    local meta = p:get_meta()
    local v    = meta:get_int(KEY_PERS) + amount
    if v < 0 then v = 0 end
    meta:set_int(KEY_PERS, v)
    tgw_core.emit("wallet_changed", { kind = "personal", player = player_name, value = v })
    return v
end

function tgw_economy.pay_personal(player_name, amount)
    if is_admin(player_name) then return true end
    local p = core.get_player_by_name(player_name)
    if not p then return false end
    local meta = p:get_meta()
    local v    = meta:get_int(KEY_PERS)
    if v < amount then return false end
    meta:set_int(KEY_PERS, v - amount)
    tgw_core.emit("wallet_changed", { kind = "personal", player = player_name, value = v - amount })
    return true
end

-- ---------------------------------------------------------------------------
-- Rewards
-- ---------------------------------------------------------------------------

local function reward(player_name, table_)
    if player_name and table_.personal > 0 then
        tgw_economy.add_personal(player_name, table_.personal)
    end
    if table_.shared > 0 then
        tgw_economy.add_shared(table_.shared)
    end
end

tgw_core.on("invader_killed", function(p)
    local killer_name = p.killer and p.killer.is_player and p.killer:is_player()
        and p.killer:get_player_name() or nil
    reward(killer_name, cfg.reward.kill)
end)

tgw_core.on("invader_captured", function(p)
    reward(p.capturer, cfg.reward.capture)
end)

tgw_core.on("wave_cleared", function()
    reward(nil, cfg.reward.wave_clear)
end)

-- ---------------------------------------------------------------------------
-- Reset hook
-- ---------------------------------------------------------------------------

tgw_core.on("world_reset", function()
    storage:set_int(KEY_SHARED, 0)
end)

core.log("action", "[tgw_economy] loaded (shared=" .. tgw_economy.get_shared() .. ")")
