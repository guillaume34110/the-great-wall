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
-- Historiques (incontestables) + Mythologiques / fictionnels iconiques.
-- texture : PNG 64×32 généré via tools/sprite_gen/generate_guardians.py.
tgw_trump_skin.GUARDIANS = {
    -- Historiques
    {
        id      = "trump",
        name    = "Donald Trump",
        blurb   = "Mur frontalier US/Mexique. Big, beautiful, expensive.",
        texture = "tgw_guardian_trump.png",
        swatch  = "#ffa040",
    },
    {
        id      = "qin",
        name    = "Qin Shi Huang",
        blurb   = "Premier Empereur — Grande Muraille de Chine, 220 av. J.-C.",
        texture = "tgw_guardian_qin.png",
        swatch  = "#992222",
    },
    {
        id      = "hadrian",
        name    = "Hadrien",
        blurb   = "Empereur romain — Mur d'Hadrien, frontière nord de Britannia.",
        texture = "tgw_guardian_hadrian.png",
        swatch  = "#b08850",
    },
    {
        id      = "vauban",
        name    = "Vauban",
        blurb   = "Maréchal de France — 160 places fortes, art de la fortification.",
        texture = "tgw_guardian_vauban.png",
        swatch  = "#3a5fa8",
    },
    -- Mythologiques / fictionnels
    {
        id      = "jon_snow",
        name    = "Jon Snow",
        blurb   = "Lord Commandant de la Garde de Nuit. Le Mur de glace, 700 pieds de haut.",
        texture = "tgw_guardian_jon_snow.png",
        swatch  = "#2a2a30",
    },
    {
        id      = "heimdall",
        name    = "Heimdall",
        blurb   = "Gardien du Bifrost. Voit à 100 lieues, entend l'herbe pousser.",
        texture = "tgw_guardian_heimdall.png",
        swatch  = "#d4a82c",
    },
    {
        id      = "gandalf",
        name    = "Gandalf",
        blurb   = "Pont de la Khazad-dûm. « You shall not pass ! »",
        texture = "tgw_guardian_gandalf.png",
        swatch  = "#c8c8d0",
    },
    {
        id      = "janus",
        name    = "Janus",
        blurb   = "Dieu romain des portes et seuils. Deux visages, un dedans, un dehors.",
        texture = "tgw_guardian_janus.png",
        swatch  = "#6a3a8a",
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
    return g.texture or "character.png"
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
    local cols   = 4
    local col_w  = 2.8
    local row_h  = 4.4
    local pad    = 0.4
    local n      = #tgw_trump_skin.GUARDIANS
    local rows   = math.ceil(n / cols)
    local width  = pad + cols * col_w + pad
    local height = 1.0 + rows * row_h + 0.4

    local fs = "formspec_version[6]size[" .. width .. "," .. height .. "]" ..
        "bgcolor[#101015FA;true]" ..
        "label[" .. pad .. ",0.5;" ..
            core.formspec_escape(S("Choose your Wall Guardian")) .. "]"

    for i, g in ipairs(tgw_trump_skin.GUARDIANS) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x   = pad + col * col_w
        local y   = 1.0 + row * row_h
        local cw  = col_w - 0.2
        local ch  = row_h - 0.2
        -- Face avant du skin (8x8 à offset 8,8 du PNG 64x32) agrandie 2.4×2.4.
        local face = "[combine:8x8:-8,-8=" .. g.texture
        fs = fs ..
            "box[" .. x .. "," .. y .. ";" .. cw .. "," .. ch .. ";#1c1c24]" ..
            "box[" .. (x + 0.1) .. "," .. (y + 0.1) .. ";" ..
                (cw - 0.2) .. ",1.0;" .. g.swatch .. "]" ..
            "image[" .. (x + cw/2 - 1.2) .. "," .. (y + 0.15) .. ";" ..
                "2.4,2.4;" .. face .. "]" ..
            "label[" .. (x + 0.2) .. "," .. (y + 2.8) .. ";" ..
                core.formspec_escape(g.name) .. "]" ..
            "tooltip[" .. x .. "," .. y .. ";" .. cw .. "," .. ch ..
                ";" .. core.formspec_escape(g.blurb) .. "]" ..
            "button_exit[" .. (x + 0.15) .. "," .. (y + ch - 0.9) ..
                ";" .. (cw - 0.3) .. ",0.75;pick_" .. g.id .. ";" ..
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
    local pname = player:get_player_name()
    for _, g in ipairs(tgw_trump_skin.GUARDIANS) do
        if fields["pick_" .. g.id] then
            player:get_meta():set_string(META_GUARDIAN, g.id)
            tgw_trump_skin.apply(player, g.id)
            core.close_formspec(pname, FORM)
            core.chat_send_player(pname,
                core.colorize("#ffcc44",
                    "[Wall] " .. S("You stand as @1.", g.name)))
            return true
        end
    end
    -- Fermeture sans choix : ré-affiche.
    if fields.quit and player:get_meta():get_string(META_GUARDIAN) == "" then
        core.after(0.5, function()
            local p = core.get_player_by_name(pname)
            if p and p:get_meta():get_string(META_GUARDIAN) == "" then
                tgw_trump_skin.show(p)
            end
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
