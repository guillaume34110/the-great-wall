-- tgw_waves : scheduler 200 vagues.
-- Compose chaque vague à partir de wave_idx + nb joueurs + nuit.
-- Émet wave_started / wave_cleared. Détecte fin via décompte ennemis.

local S = core.get_translator("tgw_waves")
tgw_waves = {}
tgw_waves.S = S

local cfg = tgw_core.config

local current_wave   = 0
local alive_count    = 0
local wave_active    = false
local wave_spawn_job = nil

function tgw_waves.get_current() return current_wave end
function tgw_waves.is_active()   return wave_active end

-- ---------------------------------------------------------------------------
-- Composition
-- ---------------------------------------------------------------------------

local function base_count(wave_idx)
    return 4 + math.floor(wave_idx * 0.6)
end

local function compose(wave_idx)
    local n_players = math.max(1, #core.get_connected_players())
    local total = math.ceil(base_count(wave_idx) * (1 + (n_players - 1) * cfg.spawn_per_player))

    local tod = core.get_timeofday()
    local is_night = (tod < 0.2 or tod > 0.8)
    if is_night then
        total = math.ceil(total * cfg.night.density_mult)
    end

    local mix = {}
    local hard_pct = is_night and cfg.night.hard_types_pct or 0
    for _ = 1, total do
        local r = math.random(100)
        if wave_idx >= 10 and r <= (15 + hard_pct / 2) then
            table.insert(mix, "digger")
        elseif wave_idx >= 5 and r <= (35 + hard_pct) then
            table.insert(mix, "tank")
        else
            table.insert(mix, "runner")
        end
    end
    return mix, is_night
end

-- ---------------------------------------------------------------------------
-- Spawn (étalé ~0.4s/mob)
-- ---------------------------------------------------------------------------

local function spawn_wave(wave_idx)
    local mix, is_night = compose(wave_idx)
    alive_count = #mix
    wave_active = true

    core.log("action", "[tgw_waves] wave " .. wave_idx ..
        " : " .. #mix .. " invaders" .. (is_night and " (NIGHT)" or ""))
    tgw_core.emit("wave_started", { index = wave_idx, count = #mix, night = is_night })
    core.chat_send_all(S("Wave @1 / @2 — @3 invaders incoming@4",
        wave_idx, cfg.waves_total, #mix, is_night and " (NIGHT)" or ""))

    local i = 0
    local function next_spawn()
        i = i + 1
        if i > #mix then wave_spawn_job = nil; return end
        local p = tgw_map.random_enemy_spawn()
        tgw_invader.spawn(mix[i], p, wave_idx)
        wave_spawn_job = core.after(0.4, next_spawn)
    end
    next_spawn()
end

-- ---------------------------------------------------------------------------
-- Décompte clear
-- ---------------------------------------------------------------------------

local function on_invader_gone()
    if not wave_active then return end
    alive_count = alive_count - 1
    if alive_count <= 0 then
        wave_active = false
        tgw_core.emit("wave_cleared", { index = current_wave })
        core.chat_send_all(S("Wave @1 cleared.", current_wave))

        if current_wave >= cfg.waves_total then
            tgw_core.set_state(tgw_core.STATE.VICTORY)
            local plist = {}
            for _, p in ipairs(core.get_connected_players()) do
                table.insert(plist, p:get_player_name())
            end
            tgw_core.emit("run_won", { players = plist, time = core.get_gametime() })
            return
        end

        core.after(8.0, function()
            if tgw_core.get_state() ~= tgw_core.STATE.RUN then return end
            current_wave = current_wave + 1
            spawn_wave(current_wave)
        end)
    end
end

tgw_core.on("invader_killed",   on_invader_gone)
tgw_core.on("invader_captured", on_invader_gone)
-- Pas invader_reached_house : l'ennemi est encore vivant à la porte, il tape
-- jusqu'à mort. Sinon il y aurait clear de vague malgré ennemis actifs.

-- Pipeline réinjection : entité de plus à compter
tgw_core.on("invader_returned", function()
    if wave_active then alive_count = alive_count + 1 end
end)

-- ---------------------------------------------------------------------------
-- Start / stop
-- ---------------------------------------------------------------------------

tgw_core.on("run_started", function()
    current_wave = 1
    wave_active  = false
    wave_spawn_job = nil
    spawn_wave(current_wave)
end)

tgw_core.on("state_changed", function(p)
    if p.to == tgw_core.STATE.DEFEAT or p.to == tgw_core.STATE.LOBBY then
        wave_active = false
        wave_spawn_job = nil
        for _, ent in pairs(core.luaentities) do
            if ent and ent.name and ent.name:sub(1, 12) == "tgw_invader:" then
                ent.object:remove()
            end
        end
        current_wave = 0
    end
end)

core.log("action", "[tgw_waves] loaded (" .. cfg.waves_total .. " waves)")
