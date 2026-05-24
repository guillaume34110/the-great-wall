-- tgw_trump_skin : sélection simple d'un Gardien du Mur historique.
-- Trump + 3 autres figures incontestables de l'art du mur.
-- 1 formspec léger sur first-join, teinte HSL appliquée à character.png.

local S = core.get_translator("tgw_trump_skin")
tgw_trump_skin = {}
tgw_trump_skin.S = S

local META_GUARDIAN = "tgw_guardian"
local FORM          = "tgw_trump_skin:pick"

-- ---------------------------------------------------------------------------
-- Roster
-- ---------------------------------------------------------------------------
-- Chaque entrée : id, name, blurb, hsl {hue, sat_delta, lum_delta}, swatch (#RRGGBB)
tgw_trump_skin.GUARDIANS = {
    {
        id    = "trump",
        name  = "Donald Trump",
        blurb = "Mur frontalier US/Mexique. Big, beautiful, expensive.",
        hsl   = { 30, 40, 5 },
        swatch = "#ffa040",
    },
    {
        id    = "qin",
        name  = "Qin Shi Huang",
        blurb = "Premier Empereur — Grande Muraille de Chine, 220 av. J.-C.",
        blurb_short = "Grande Muraille de Chine",
        hsl   = { 0, 50, -15 },
        swatch = "#992222",
    },
    {
        id    = "hadrian",
        name  = "Hadrien",
        blurb = "Empereur romain — Mur d'Hadrien, frontière nord de Britannia.",
        hsl   = { 40, 20, -10 },
        swatch = "#b08850",
    },
    {
        id    = "vauban",
        name  = "Vauban",
        blurb = "Maréchal de France — 160 places fortes, art de la fortification.",
        hsl   = { 210, 40, -10 },
        swatch = "#3a5fa8",
    },
}

local function find(id)
    for _, g in ipairs(tgw_trump_skin.GUARDIANS) do
        if g.id == id then return g end
    end
    return tgw_trump_skin.GUARDIANS[1]
end

-- ---------------------------------------------------------------------------
-- Apply
-- ---------------------------------------------------------------------------
local function texture_for(g)
    local h, s, l = g.hsl[1] or 0, g.hsl[2] or 0, g.hsl[3] or 0
    return string.format("character.png^[hsl:%d:%d:%d", h, s, l)
end

function tgw_trump_skin.apply(player, guardian_id)
    if not player or not player:is_player() then return end
    local g = find(guardian_id or player:get_meta():get_string(META_GUARDIAN))
    if player_api.set_textures then
        player_api.set_textures(player, { texture_for(g) })
    end
    player:set_properties({ visual_size = { x = 1.0, y = 1.0 } })
end

function tgw_trump_skin.get(player)
    if not player or not player:is_player() then return nil end
    local id = player:get_meta():get_string(META_GUARDIAN)
    if id == "" then return nil end
    return find(id)
end

-- ---------------------------------------------------------------------------
-- Formspec
-- ---------------------------------------------------------------------------
local function build_fs()
    local n = #tgw_trump_skin.GUARDIANS
    local col_w  = 3.4
    local pad    = 0.3
    local width  = pad + n * col_w + pad
    local height = 6.2

    local fs = "formspec_version[6]size[" .. width .. "," .. height .. "]" ..
        "bgcolor[#101015FA;true]" ..
        "label[" .. pad .. ",0.5;" ..
            core.formspec_escape(S("Choose your Wall Guardian")) .. "]"

    for i, g in ipairs(tgw_trump_skin.GUARDIANS) do
        local x = pad + (i - 1) * col_w
        -- carte
        fs = fs ..
            "box[" .. x .. ",1.0;" .. (col_w - 0.2) .. ",4.6;#1c1c24]" ..
            -- swatch (gros bloc couleur "portrait")
            "box[" .. (x + 0.4) .. ",1.2;" .. (col_w - 1.0) .. ",1.8;" .. g.swatch .. "]" ..
            "label[" .. (x + 0.4) .. ",3.2;" .. core.formspec_escape(g.name) .. "]" ..
            "textarea[" .. (x + 0.3) .. ",3.5;" .. (col_w - 0.6) ..
                ",1.4;;;" .. core.formspec_escape(g.blurb) .. "]" ..
            "button[" .. (x + 0.3) .. ",5.0;" .. (col_w - 0.6) ..
                ",0.8;pick_" .. g.id .. ";" ..
                core.formspec_escape(S("Defend!")) .. "]"
    end
    return fs
end

function tgw_trump_skin.show(player)
    if not player or not player:is_player() then return end
    core.show_formspec(player:get_player_name(), FORM, build_fs())
end

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORM then return end
    for _, g in ipairs(tgw_trump_skin.GUARDIANS) do
        if fields["pick_" .. g.id] then
            player:get_meta():set_string(META_GUARDIAN, g.id)
            tgw_trump_skin.apply(player, g.id)
            core.chat_send_player(player:get_player_name(),
                core.colorize("#ffcc44",
                    "[Wall] " .. S("You stand as @1.", g.name)))
            return true
        end
    end
    -- Joueur tente de fermer sans choisir → ré-affiche.
    if fields.quit and player:get_meta():get_string(META_GUARDIAN) == "" then
        core.after(0.3, function()
            local p = core.get_player_by_name(player:get_player_name())
            if p then tgw_trump_skin.show(p) end
        end)
        return true
    end
end)

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

core.register_on_joinplayer(function(player)
    core.after(0.4, function()
        if not (player and player:is_player()) then return end
        local id = player:get_meta():get_string(META_GUARDIAN)
        if id == "" then
            tgw_trump_skin.show(player)
        else
            tgw_trump_skin.apply(player, id)
        end
    end)
end)

core.register_on_respawnplayer(function(player)
    core.after(0.4, function()
        if player and player:is_player() then
            tgw_trump_skin.apply(player)
        end
    end)
end)

-- Admin : reset
core.register_chatcommand("guardian_reset", {
    description = "Reset choix de gardien (admin)",
    params = "<pname>",
    privs = { server = true },
    func = function(_, target)
        local p = core.get_player_by_name(target)
        if not p then return false, "joueur hors-ligne" end
        p:get_meta():set_string(META_GUARDIAN, "")
        tgw_trump_skin.show(p)
        return true, "guardian reset pour " .. target
    end,
})

core.log("action", "[tgw_trump_skin] loaded (" ..
    #tgw_trump_skin.GUARDIANS .. " guardians)")
