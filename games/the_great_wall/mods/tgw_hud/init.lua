-- tgw_hud : HUD overlay (vague, wallets, HP porte, état).

local S = core.get_translator("tgw_hud")
tgw_hud = {}
tgw_hud.S = S

-- player_name -> { hud_id = ... }
local huds = {}

local function build_text(name)
    local state = tgw_core.get_state()
    local wave  = tgw_waves.get_current()
    local pers  = tgw_economy.get_personal(name)
    local shar  = tgw_economy.get_shared()
    local door  = (tgw_house and tgw_house.get_door_hp) and tgw_house.get_door_hp() or 0
    return string.format(
        "[%s]  Wave %d/%d   $perso:%d   $commun:%d   Porte:%d HP",
        state:upper(), wave, tgw_core.config.waves_total, pers, shar, door
    )
end

local function attach(player)
    local name = player:get_player_name()
    local id = player:hud_add({
        hud_elem_type = "text",
        position      = { x = 0.5, y = 0.02 },
        offset        = { x = 0, y = 20 },
        alignment     = { x = 0, y = 1 },
        scale         = { x = 100, y = 100 },
        text          = build_text(name),
        number        = 0xFFFFFF,
    })
    huds[name] = { id = id }
end

function tgw_hud.refresh(player)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    local h = huds[name]
    if not h then return end
    player:hud_change(h.id, "text", build_text(name))
end

function tgw_hud.refresh_all()
    for _, p in ipairs(core.get_connected_players()) do tgw_hud.refresh(p) end
end

core.register_on_joinplayer(function(player)
    attach(player)
end)

core.register_on_leaveplayer(function(player)
    huds[player:get_player_name()] = nil
end)

-- Refresh sur events pertinents
for _, ev in ipairs({
    "wallet_changed", "wave_started", "wave_cleared", "door_damaged",
    "state_changed", "invader_killed", "invader_captured",
}) do
    tgw_core.on(ev, function() tgw_hud.refresh_all() end)
end

-- Tick fallback (1s)
local function tick()
    tgw_hud.refresh_all()
    core.after(1.0, tick)
end
core.after(2.0, tick)

core.log("action", "[tgw_hud] loaded")
