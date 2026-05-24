-- Slot UNIQUE par joueur + règles de mix anti-flapping.
--
-- Règles :
--  1. Un seul son joue à la fois (slot_handle). Stop précédent avant play.
--  2. Min-dwell 30s sur un ambient avant switch → réduit le clignotement
--     en zone frontière. Bypassé pour transitions urgentes (combat/boss/death).
--  3. Gap silencieux entre tracks pour éviter overlap audible :
--     - 1.5s entre deux ambients (laisse respirer)
--     - 0.0s vers combat/boss (impact immédiat)
--     - 0.5s pour stingers
--  4. Stinger = bloque l'override ambient pendant `duration`. À expiration,
--     l'ambient reprend automatiquement.
--  5. Pas de relance si même slug que le slot courant.

local S = {}
lumia_music.state = S

local tracks = lumia_music.tracks
local triggers = lumia_music.triggers

local function settings_float(k, d)
    local v = minetest.settings:get(k)
    if v then return tonumber(v) or d end
    return d
end

local MASTER_GAIN     = settings_float("lumia.music_master_gain", 0.5)
local TICK            = settings_float("lumia.music_tick", 2.0)
local COMBAT_TIMEOUT  = settings_float("lumia.music_combat_timeout", 8.0)
local MIN_DWELL       = settings_float("lumia.music_min_dwell", 30.0)
local GAP_AMBIENT     = settings_float("lumia.music_gap_ambient", 1.5)
local GAP_URGENT      = settings_float("lumia.music_gap_urgent", 0.0)
local GAP_STINGER     = settings_float("lumia.music_gap_stinger", 0.5)

local URGENT = {combat = true, boss = true}

local players = {}

local function now() return minetest.get_us_time() / 1e6 end

local function stop_handle(h)
    if h then pcall(minetest.sound_stop, h) end
end

function S.init_player(player)
    players[player:get_player_name()] = {
        slot_handle = nil,
        slot_slug = nil,
        slot_is_stinger = false,
        slot_started_at = 0,
        stinger_until = 0,
        combat_until = 0,
        boss_until = 0,
    }
end

function S.remove_player(name)
    local st = players[name]
    if st then
        stop_handle(st.slot_handle)
        players[name] = nil
    end
    triggers.reset_player(name)
end

function S.get(name) return players[name] end

function S.mark_combat(name, duration)
    local st = players[name]
    if st then st.combat_until = now() + (duration or COMBAT_TIMEOUT) end
end

function S.mark_boss(name, duration)
    local st = players[name]
    if st then st.boss_until = now() + (duration or COMBAT_TIMEOUT) end
end

local function pick_ambient_slug(player, st)
    local t = now()
    if st.boss_until > t then return "boss" end
    if st.combat_until > t then return "combat" end
    return triggers.pick_ambient(player)
end

local function play_in_slot(player_name, slug, is_stinger, gap)
    local st = players[player_name]
    if not st then return end
    if st.slot_slug == slug and not is_stinger then return end  -- déjà en cours

    local sound, def = tracks.pick_sound(slug)
    if not sound or not def then return end

    stop_handle(st.slot_handle)
    st.slot_handle = nil
    st.slot_slug = slug
    st.slot_is_stinger = is_stinger
    st.slot_started_at = now() + (gap or 0)
    st.stinger_until = is_stinger and (now() + (gap or 0) + (def.duration or 60)) or 0

    local g = (def.gain or 0.5) * MASTER_GAIN
    local loop = (def.type == "loop")

    minetest.after(gap or 0, function()
        if not players[player_name] then return end
        if players[player_name].slot_slug ~= slug then return end
        local h = minetest.sound_play(sound, {
            to_player = player_name,
            gain = g,
            loop = loop,
        })
        players[player_name].slot_handle = h
    end)
    minetest.log("action", string.format(
        "[lumia_music] %s -> %s (%s%s, gap=%.1fs)",
        player_name, slug, sound, is_stinger and " stinger" or "", gap or 0))
end

function S.play_stinger(player_name, slug)
    if not tracks.get(slug) then return end
    play_in_slot(player_name, slug, true, GAP_STINGER)
end

local accum = 0
function S.on_step(dtime)
    accum = accum + dtime
    if accum < TICK then return end
    accum = 0

    local t = now()
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local st = players[name]
        if not st then S.init_player(player); st = players[name] end

        -- Stinger en cours : on n'override pas.
        if st.stinger_until > t and st.slot_is_stinger then
            -- pass
        else
            local desired = pick_ambient_slug(player, st)
            if not desired or desired == st.slot_slug then
                -- rien à faire
            else
                local cur = st.slot_slug
                local desired_urgent = URGENT[desired] or false
                local cur_urgent = URGENT[cur] or false
                local age = t - (st.slot_started_at or 0)

                local allow, gap
                if desired_urgent and not cur_urgent then
                    allow, gap = true, GAP_URGENT  -- impact combat/boss
                elseif cur_urgent and not desired_urgent then
                    allow, gap = age >= 2.0, GAP_AMBIENT  -- petit délai pour ne pas couper trop net
                else
                    -- ambient ↔ ambient : min dwell
                    allow, gap = age >= MIN_DWELL, GAP_AMBIENT
                end

                if allow then
                    play_in_slot(name, desired, false, gap)
                end
            end
        end
    end
end
