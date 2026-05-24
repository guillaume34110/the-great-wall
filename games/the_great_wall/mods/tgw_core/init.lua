-- tgw_core : state machine + event bus + shared config for The Great Wall.

local S = core.get_translator("tgw_core")
tgw_core = {}
tgw_core.S = S

tgw_core.STATE = {
    LOBBY   = "lobby",    -- attente, joueurs join, mur visible, bouton dispo
    RUN     = "run",      -- 200 vagues actives
    DEFEAT  = "defeat",   -- porte cassée, attente reset
    VICTORY = "victory",  -- vague 200 OK, attente reset
}

tgw_core.config = {
    wall_length      = 150,
    wall_height      = 6,
    wall_node_hp     = 50,
    door_hp          = 200,
    waves_total      = 200,
    respawn_cooldown = 10,           -- secondes
    spawn_per_player = 1.0,          -- multiplicateur de spawn-rate par joueur
    pipeline_return_pct = 50,        -- % d'ennemis capturés qui reviennent
    reward = {
        kill        = { personal = 5,  shared = 1 },
        capture     = { personal = 10, shared = 1 }, -- prime à l'entrée du tuyau
        wave_clear  = { personal = 0,  shared = 20 },
    },
    night = {
        density_mult = 1.5,
        hard_types_pct = 30,
    },
}

-- ---------------------------------------------------------------------------
-- State machine
-- ---------------------------------------------------------------------------

local current_state = tgw_core.STATE.LOBBY
local listeners = {}  -- event_name -> { fn, fn, ... }

function tgw_core.get_state()
    return current_state
end

function tgw_core.set_state(new_state)
    if new_state == current_state then return end
    local old = current_state
    current_state = new_state
    core.log("action", "[tgw_core] state " .. old .. " -> " .. new_state)
    tgw_core.emit("state_changed", { from = old, to = new_state })
end

-- ---------------------------------------------------------------------------
-- Event bus (publish/subscribe between tgw_* mods)
-- ---------------------------------------------------------------------------

function tgw_core.on(event_name, fn)
    listeners[event_name] = listeners[event_name] or {}
    table.insert(listeners[event_name], fn)
end

function tgw_core.emit(event_name, payload)
    local subs = listeners[event_name]
    if not subs then return end
    for _, fn in ipairs(subs) do
        local ok, err = pcall(fn, payload)
        if not ok then
            core.log("error", "[tgw_core] listener for " .. event_name .. " failed: " .. tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Known events (documentation)
-- ---------------------------------------------------------------------------
-- "state_changed"   { from, to }
-- "run_started"     { players }
-- "wave_started"    { index }
-- "wave_cleared"    { index }
-- "invader_killed"  { invader, killer }
-- "invader_captured"{ invader, capturer }
-- "invader_returned"{ invader }            -- 50% retour pipeline
-- "invader_reached_house" { invader }
-- "door_damaged"    { hp_left, dmg }
-- "wall_damaged"    { pos, hp_left }
-- "run_won"         { players, time }
-- "run_lost"        { wave_reached }
-- "world_reset"     {}

core.log("action", "[tgw_core] loaded")
