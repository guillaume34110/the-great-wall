-- tgw_hof : Hall of Fame persistant à travers les resets de monde.
-- Stocke dans un fichier hors worldpath (parent dir), pour survivre à WIPE=1.

local S = core.get_translator("tgw_hof")
tgw_hof = {}
tgw_hof.S = S

-- ---------------------------------------------------------------------------
-- Storage : fichier hors worldpath (parent), survit au wipe du monde
-- ---------------------------------------------------------------------------

local HOF_PATH = core.get_worldpath() .. "/../hof.json"
local MAX_ENTRIES = 50

local function load_entries()
    local f = io.open(HOF_PATH, "r")
    if not f then return {} end
    local raw = f:read("*a")
    f:close()
    local t = core.parse_json(raw or "")
    if type(t) ~= "table" then return {} end
    return t
end

local function save_entries(t)
    local raw = core.write_json(t)
    if not raw then return end
    core.safe_file_write(HOF_PATH, raw)
end

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

-- entry : { players = {...}, wave_reached = N, victory = bool, date = "YYYY-MM-DD HH:MM", time_s = N }
function tgw_hof.record(player_names, wave_reached, victory, time_s)
    local entries = load_entries()
    table.insert(entries, {
        players      = player_names or {},
        wave_reached = wave_reached or 0,
        victory      = victory and true or false,
        date         = os.date("%Y-%m-%d %H:%M"),
        time_s       = time_s or 0,
    })
    -- Tri : victoires d'abord, puis vague atteinte desc, puis temps asc
    table.sort(entries, function(a, b)
        if a.victory ~= b.victory then return a.victory end
        if a.wave_reached ~= b.wave_reached then return a.wave_reached > b.wave_reached end
        return (a.time_s or 0) < (b.time_s or 0)
    end)
    while #entries > MAX_ENTRIES do table.remove(entries) end
    save_entries(entries)
    core.log("action", "[tgw_hof] recorded run (wave=" .. (wave_reached or 0) ..
        " victory=" .. tostring(victory) .. ")")
end

function tgw_hof.top(n)
    n = n or 10
    local entries = load_entries()
    local out = {}
    for i = 1, math.min(n, #entries) do out[i] = entries[i] end
    return out
end

-- ---------------------------------------------------------------------------
-- Tracking run start time (pour calculer time_s)
-- ---------------------------------------------------------------------------

local run_start_us = nil
local run_players  = {}

tgw_core.on("run_started", function(p)
    run_start_us = core.get_us_time()
    run_players  = {}
    for _, pl in ipairs(core.get_connected_players()) do
        table.insert(run_players, pl:get_player_name())
    end
end)

local function elapsed_s()
    if not run_start_us then return 0 end
    return math.floor((core.get_us_time() - run_start_us) / 1e6)
end

tgw_core.on("run_won", function(p)
    local wave = (p and p.wave) or tgw_core.config.waves_total
    tgw_hof.record(run_players, wave, true, elapsed_s())
end)

tgw_core.on("run_lost", function(p)
    local wave = (p and p.wave_reached) or 0
    tgw_hof.record(run_players, wave, false, elapsed_s())
end)

-- ---------------------------------------------------------------------------
-- Formspec /hof
-- ---------------------------------------------------------------------------

local function build_fs()
    local entries = tgw_hof.top(10)
    local fs = "formspec_version[6]size[12,11]" ..
        "label[0.4,0.5;" .. core.formspec_escape(S("HALL OF FAME — Top 10")) .. "]" ..
        "label[0.4,1.1;#  Vague  Temps   Players                                    Date]"
    local y = 1.7
    for i, e in ipairs(entries) do
        local mark = e.victory and "WIN " or "    "
        local mm = math.floor((e.time_s or 0) / 60)
        local ss = (e.time_s or 0) % 60
        local players = table.concat(e.players or {}, ",")
        if #players > 40 then players = players:sub(1, 37) .. "..." end
        local line = string.format("%2d. %s W%-3d %02d:%02d  %-40s  %s",
            i, mark, e.wave_reached or 0, mm, ss, players, e.date or "")
        fs = fs .. "label[0.4," .. y .. ";" .. core.formspec_escape(line) .. "]"
        y = y + 0.55
    end
    if #entries == 0 then
        fs = fs .. "label[0.4,3.0;" .. core.formspec_escape(S("(no runs recorded yet)")) .. "]"
    end
    fs = fs .. "button_exit[4.5,10.0;3,0.8;close;" .. core.formspec_escape(S("Close")) .. "]"
    return fs
end

function tgw_hof.show(player)
    if not player or not player:is_player() then return end
    core.show_formspec(player:get_player_name(), "tgw_hof:main", build_fs())
end

core.register_chatcommand("hof", {
    description = S("Show Hall of Fame"),
    func = function(name)
        local p = core.get_player_by_name(name)
        if p then tgw_hof.show(p) end
        return true
    end,
})

core.log("action", "[tgw_hof] loaded (path=" .. HOF_PATH .. ")")
