-- Formspec multi-pages : race → variante → classe → signe → résumé.
-- Verrouille le joueur tant que pas confirmé.

local R = lumia_chargen.races
local SIGNS = lumia_chargen.signs
local FORM = "lumia_chargen:create"
local STATE = {}  -- pname → {page, race_idx, variant_idx, class_idx, sign_idx, spec_idx, charname, major, minor}
local SPECS = {"combat", "magic", "stealth"}

local function init_state(pname)
    STATE[pname] = {
        page = 1,
        race_idx = 1,
        variant_idx = 1,
        class_idx = 1,
        sign_idx = 1,
        spec_idx = 1,
        charname = pname,
        major = {},
        minor = {},
    }
    return STATE[pname]
end

local function get_state(pname)
    return STATE[pname] or init_state(pname)
end

local function attr_mods_str(mods)
    local parts = {}
    local order = {"strength", "endurance", "agility", "speed",
                   "intelligence", "willpower", "personality", "luck"}
    local short = {strength="STR", endurance="END", agility="AGI", speed="SPD",
                   intelligence="INT", willpower="WIL", personality="PER", luck="LUK"}
    for _, k in ipairs(order) do
        local v = mods[k]
        if v and v ~= 0 then
            local sign = (v > 0) and "+" or ""
            parts[#parts+1] = string.format("%s%s%d", short[k], sign, v)
        end
    end
    return table.concat(parts, " ")
end

local function preview_texture(race, variant)
    local h = (variant.hsl[1] or 0)
    local s = (variant.hsl[2] or 0)
    local l = (variant.hsl[3] or 0)
    return string.format("character.png^[hsl:%d:%d:%d", h, s, l)
end

local function model_element(x, y, w, h, name, race, variant)
    local tex = preview_texture(race, variant)
    -- character.b3d : idle anim ≈ frames 0-79, rotation Y 180° pour faire face caméra
    return string.format(
        "model[%.2f,%.2f;%.2f,%.2f;%s;character.b3d;%s;0,180;false;true;0,80;15]",
        x, y, w, h, name, minetest.formspec_escape(tex))
end

local function build_page1(pname)
    local st = get_state(pname)
    local race = R.races[st.race_idx]
    local variant = race.variants[1]
    local fs = {
        "formspec_version[6]",
        "size[14,11]",
        "no_prepend[]",
        "bgcolor[#0a0a14ee;false]",
        "label[0.5,0.5;" .. minetest.colorize("#ffd27f", "Création de Personnage — Race") .. "]",
        "label[0.5,0.95;" .. minetest.colorize("#aaaaaa",
            "Choisis ta race. Chaque race a son lore, ses modificateurs d'attributs et un trait passif.") .. "]",
    }
    local race_list = {}
    for _, r in ipairs(R.races) do
        race_list[#race_list+1] = minetest.formspec_escape(r.name)
    end
    fs[#fs+1] = "textlist[0.5,1.6;4.2,8;race_list;" .. table.concat(race_list, ",") .. ";"
        .. st.race_idx .. ";false]"
    -- Aperçu 3D (rotation Y interactive à la souris)
    fs[#fs+1] = "box[5.0,1.6;3.5,7.5;#1a1a2a]"
    fs[#fs+1] = model_element(5.0, 1.6, 3.5, 7.5, "race_preview", race, variant)
    fs[#fs+1] = "label[5.0,9.2;" .. minetest.colorize("#888888", "(glisse pour tourner)") .. "]"
    -- Détail à droite
    fs[#fs+1] = "label[8.8,1.6;" .. minetest.colorize("#ffd27f", race.name) .. "]"
    fs[#fs+1] = "textarea[8.8,2.0;5,2.0;;;" .. minetest.formspec_escape(race.lore) .. "]"
    fs[#fs+1] = "label[8.8,4.0;" .. minetest.colorize("#88ddff", "Modificateurs : ") .. "]"
    fs[#fs+1] = "label[8.8,4.4;" .. attr_mods_str(race.attr_mods) .. "]"
    fs[#fs+1] = "label[8.8,4.9;" .. minetest.colorize("#88ddff", "Taille : ")
        .. string.format("×%.2f", race.size or 1.0) .. "]"
    fs[#fs+1] = "label[8.8,5.4;" .. minetest.colorize("#aaffaa", "Trait : ") .. "]"
    fs[#fs+1] = "textarea[8.8,5.8;5,3.5;;;" .. minetest.formspec_escape(race.trait) .. "]"
    fs[#fs+1] = "button[11,9.8;2.5,0.9;next;Suivant ▶]"
    return table.concat(fs)
end

local function build_page2(pname)
    local st = get_state(pname)
    local race = R.races[st.race_idx]
    local variant = race.variants[st.variant_idx]
    local fs = {
        "formspec_version[6]",
        "size[14,11]",
        "bgcolor[#0a0a14ee;false]",
        "label[0.5,0.5;" .. minetest.colorize("#ffd27f",
            "Création — Variante (" .. race.name .. ")") .. "]",
        "label[0.5,0.95;" .. minetest.colorize("#aaaaaa",
            "Choisis l'apparence bipède. Toutes utilisent le même squelette ; teinte et silhouette varient.") .. "]",
    }
    local var_list = {}
    for _, v in ipairs(race.variants) do
        var_list[#var_list+1] = minetest.formspec_escape(v.name)
    end
    fs[#fs+1] = "textlist[0.5,1.6;4.2,5;variant_list;" .. table.concat(var_list, ",") .. ";"
        .. st.variant_idx .. ";false]"
    -- Aperçu 3D variante sélectionnée (texture HSL appliquée)
    fs[#fs+1] = "box[5.0,1.6;3.5,7.5;#1a1a2a]"
    fs[#fs+1] = model_element(5.0, 1.6, 3.5, 7.5, "variant_preview", race, variant)
    fs[#fs+1] = "label[5.0,9.2;" .. minetest.colorize("#888888", "(glisse pour tourner)") .. "]"
    fs[#fs+1] = "label[8.8,1.6;" .. minetest.colorize("#ffd27f", variant.name) .. "]"
    fs[#fs+1] = "label[8.8,2.1;Teinte HSL : H="
        .. variant.hsl[1] .. "  S=" .. variant.hsl[2] .. "  L=" .. variant.hsl[3] .. "]"
    fs[#fs+1] = "label[8.8,2.6;Squelette : character.b3d (bipède)]"
    fs[#fs+1] = "label[8.8,3.1;Taille : " .. string.format("×%.2f", race.size or 1.0) .. "]"
    fs[#fs+1] = "button[0.5,9.8;2.5,0.9;back;◀ Retour]"
    fs[#fs+1] = "button[11,9.8;2.5,0.9;next;Suivant ▶]"
    return table.concat(fs)
end

local function class_skills_label(c)
    if c.id == "custom" then
        return "Choix libre 5+5 (page suivante)"
    end
    return minetest.colorize("#aaffaa", "Majeurs : ") .. table.concat(c.major, ", ")
        .. "\n" .. minetest.colorize("#88ddff", "Mineurs : ") .. table.concat(c.minor, ", ")
end

local function build_page3(pname)
    local st = get_state(pname)
    local class = R.classes[st.class_idx]
    local fs = {
        "formspec_version[6]",
        "size[14,11]",
        "bgcolor[#0a0a14ee;false]",
        "label[0.5,0.5;" .. minetest.colorize("#ffd27f", "Création — Classe") .. "]",
        "label[0.5,0.95;" .. minetest.colorize("#aaaaaa",
            "5 majeurs ×1.0 XP, 5 mineurs ×0.75 XP, autres misc ×0.5 XP. La classe oriente ta progression.") .. "]",
    }
    local class_list = {}
    for _, c in ipairs(R.classes) do
        class_list[#class_list+1] = minetest.formspec_escape(c.name)
    end
    fs[#fs+1] = "textlist[0.5,1.6;5,5;class_list;" .. table.concat(class_list, ",") .. ";"
        .. st.class_idx .. ";false]"
    fs[#fs+1] = "label[6,1.6;" .. minetest.colorize("#ffd27f", class.name) .. "]"
    fs[#fs+1] = "textarea[6,2.0;7.5,1.5;;;" .. minetest.formspec_escape(class.desc) .. "]"
    fs[#fs+1] = "textarea[6,3.6;7.5,3.5;;;" .. minetest.formspec_escape(class_skills_label(class)) .. "]"
    fs[#fs+1] = "label[6,7.2;" .. minetest.colorize("#88ddff", "Bonus attrs : ")
        .. attr_mods_str(class.attr_bonus) .. "]"
    if class.id == "custom" then
        fs[#fs+1] = "label[0.5,7.0;Sélection libre : tu choisiras 5+5 sur la page de résumé.]"
    end
    fs[#fs+1] = "field[0.5,8.0;6,0.8;charname;Nom du personnage;"
        .. minetest.formspec_escape(st.charname) .. "]"
    fs[#fs+1] = "button[0.5,9.8;2.5,0.9;back;◀ Retour]"
    fs[#fs+1] = "button[11,9.8;2.5,0.9;next;Suivant ▶]"
    return table.concat(fs)
end

local function sign_desc(sg)
    local lines = {sg.lore}
    if sg.attr_mods then
        local parts = {}
        for k, v in pairs(sg.attr_mods) do
            local sign = (v > 0) and "+" or ""
            parts[#parts+1] = string.format("%s%s%d", k:sub(1,3):upper(), sign, v)
        end
        if #parts > 0 then lines[#lines+1] = "Attrs : " .. table.concat(parts, " ") end
    end
    if sg.skill_mods then
        local parts = {}
        for k, v in pairs(sg.skill_mods) do
            parts[#parts+1] = string.format("%s+%d", k, v)
        end
        if #parts > 0 then lines[#lines+1] = "Skills : " .. table.concat(parts, " ") end
    end
    if sg.magicka_mult then
        lines[#lines+1] = string.format("Magicka ×%.1f", sg.magicka_mult)
    end
    if sg.regen_hp then lines[#lines+1] = string.format("Régen HP +%.1f/s", sg.regen_hp) end
    if sg.resist_fire then lines[#lines+1] = string.format("Résist feu %d%%", sg.resist_fire * 100) end
    if sg.resist_magic then lines[#lines+1] = string.format("Résist magie %d%%", sg.resist_magic * 100) end
    if sg.absorb_magic then lines[#lines+1] = string.format("Absorbe magie %d%%", sg.absorb_magic * 100) end
    if sg.sprint_no_drain then lines[#lines+1] = "Pas de drain de fatigue à la course" end
    return table.concat(lines, "\n")
end

local function build_page4(pname)
    local st = get_state(pname)
    local sign = SIGNS.signs[st.sign_idx]
    local fs = {
        "formspec_version[6]",
        "size[14,11]",
        "bgcolor[#0a0a14ee;false]",
        "label[0.5,0.5;" .. minetest.colorize("#ffd27f", "Création — Signe de Naissance") .. "]",
        "label[0.5,0.95;" .. minetest.colorize("#aaaaaa",
            "Choisis ta constellation. Bonus passifs permanents.") .. "]",
    }
    local list = {}
    for _, s in ipairs(SIGNS.signs) do list[#list+1] = minetest.formspec_escape(s.name) end
    fs[#fs+1] = "textlist[0.5,1.6;5,8;sign_list;" .. table.concat(list, ",") .. ";"
        .. st.sign_idx .. ";false]"
    fs[#fs+1] = "label[6,1.6;" .. minetest.colorize("#ffd27f", sign.name) .. "]"
    fs[#fs+1] = "textarea[6,2.0;7.5,7;;;" .. minetest.formspec_escape(sign_desc(sign)) .. "]"
    fs[#fs+1] = "button[0.5,9.8;2.5,0.9;back;◀ Retour]"
    fs[#fs+1] = "button[11,9.8;2.5,0.9;next;Suivant ▶]"
    return table.concat(fs)
end

local function build_page5(pname)
    local st = get_state(pname)
    local race = R.races[st.race_idx]
    local variant = race.variants[st.variant_idx]
    local class = R.classes[st.class_idx]
    local sign = SIGNS.signs[st.sign_idx]
    local fs = {
        "formspec_version[6]",
        "size[14,11]",
        "bgcolor[#0a0a14ee;false]",
        "label[0.5,0.5;" .. minetest.colorize("#ffd27f", "Création — Résumé") .. "]",
    }
    local lines = {
        minetest.colorize("#ffd27f", "Nom : ") .. (st.charname or pname),
        minetest.colorize("#ffd27f", "Race : ") .. race.name .. " (" .. variant.name .. ")",
        minetest.colorize("#ffd27f", "Classe : ") .. class.name .. " [spec: " .. (class.id == "custom" and SPECS[st.spec_idx] or class.spec) .. "]",
        minetest.colorize("#ffd27f", "Signe : ") .. sign.name,
        "",
        minetest.colorize("#88ddff", "Modificateurs race : ") .. attr_mods_str(race.attr_mods),
        minetest.colorize("#88ddff", "Bonus classe : ") .. attr_mods_str(class.attr_bonus),
        minetest.colorize("#aaffaa", "Trait : ") .. race.trait,
    }
    if class.id ~= "custom" then
        lines[#lines+1] = ""
        lines[#lines+1] = minetest.colorize("#aaffaa", "Majeurs : ") .. table.concat(class.major, ", ")
        lines[#lines+1] = minetest.colorize("#88ddff", "Mineurs : ") .. table.concat(class.minor, ", ")
    end
    fs[#fs+1] = "textarea[0.5,1.2;13,3.5;;;" .. minetest.formspec_escape(table.concat(lines, "\n")) .. "]"
    if class.id == "custom" then
        local all = R.all_skills()
        fs[#fs+1] = "label[0.5,4.8;Spécialisation :]"
        for i, sp in ipairs(SPECS) do
            local lbl = (i == st.spec_idx) and ("● " .. sp) or sp
            fs[#fs+1] = string.format("button[%.2f,5.0;2,0.6;spec_%s;%s]",
                2.0 + (i-1) * 2.2, sp, lbl)
        end
        fs[#fs+1] = "label[0.5,5.7;Choisis 5 majeurs (M) et 5 mineurs (m). Le reste = misc.]"
        local x = 0.5
        local y = 6.0
        for i, sk in ipairs(all) do
            local px = x + ((i - 1) % 6) * 2.2
            local py = y + math.floor((i - 1) / 6) * 0.7
            local maj = false
            for _, m in ipairs(st.major) do if m == sk then maj = true end end
            local min = false
            for _, m in ipairs(st.minor) do if m == sk then min = true end end
            local lbl = sk
            if maj then lbl = "[M] " .. sk
            elseif min then lbl = "[m] " .. sk end
            fs[#fs+1] = string.format("button[%.2f,%.2f;2.1,0.6;sk_%s;%s]",
                px, py, sk, minetest.formspec_escape(lbl))
        end
        fs[#fs+1] = "label[0.5,9.3;" .. string.format(
            "Majeurs : %d/5 — Mineurs : %d/5", #st.major, #st.minor) .. "]"
    end
    fs[#fs+1] = "button[0.5,9.8;2.5,0.9;back;◀ Retour]"
    fs[#fs+1] = "button_exit[10.5,9.8;3,0.9;confirm;✦ Confirmer ✦]"
    return table.concat(fs)
end

local function show(pname)
    local st = get_state(pname)
    local fs
    if st.page == 1 then fs = build_page1(pname)
    elseif st.page == 2 then fs = build_page2(pname)
    elseif st.page == 3 then fs = build_page3(pname)
    elseif st.page == 4 then fs = build_page4(pname)
    else fs = build_page5(pname) end
    minetest.show_formspec(pname, FORM, fs)
end

local function trigger_chargen(player)
    local pname = player:get_player_name()
    init_state(pname)
    lumia_chargen.freeze(player)
    -- Petit délai pour laisser le client se connecter avant le formspec.
    minetest.after(0.5, function()
        if minetest.get_player_by_name(pname) then show(pname) end
    end)
end

minetest.register_on_newplayer(function(player)
    trigger_chargen(player)
end)

-- Fallback : un joueur existant sans flag = doit faire le chargen aussi.
minetest.register_on_joinplayer(function(player)
    if not lumia_chargen.is_done(player:get_player_name()) then
        trigger_chargen(player)
    end
end)

minetest.register_on_leaveplayer(function(player)
    STATE[player:get_player_name()] = nil
end)

-- Empêche le joueur de fermer le formspec sans confirmer.
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORM then return end
    local pname = player:get_player_name()
    local st = get_state(pname)
    if fields.race_list then
        local ev = minetest.explode_textlist_event(fields.race_list)
        if ev.index then
            st.race_idx = ev.index
            st.variant_idx = 1
            show(pname)
            return true
        end
    end
    if fields.variant_list then
        local ev = minetest.explode_textlist_event(fields.variant_list)
        if ev.index then
            st.variant_idx = ev.index
            show(pname)
            return true
        end
    end
    if fields.class_list then
        local ev = minetest.explode_textlist_event(fields.class_list)
        if ev.index then
            st.class_idx = ev.index
            show(pname)
            return true
        end
    end
    if fields.sign_list then
        local ev = minetest.explode_textlist_event(fields.sign_list)
        if ev.index then
            st.sign_idx = ev.index
            show(pname)
            return true
        end
    end
    for k, _ in pairs(fields) do
        local sp = k:match("^spec_(.+)$")
        if sp then
            for i, v in ipairs(SPECS) do if v == sp then st.spec_idx = i end end
            show(pname)
            return true
        end
    end
    if fields.charname and fields.charname ~= "" then
        st.charname = fields.charname
    end
    -- skill toggle (custom class)
    for k, _ in pairs(fields) do
        local sk = k:match("^sk_(.+)$")
        if sk then
            -- Cycle : misc → major → minor → misc.
            local in_major, in_minor = false, false
            for i, s in ipairs(st.major) do if s == sk then table.remove(st.major, i); in_major = true; break end end
            for i, s in ipairs(st.minor) do if s == sk then table.remove(st.minor, i); in_minor = true; break end end
            if in_major then
                if #st.minor < 5 then table.insert(st.minor, sk) end
            elseif in_minor then
                -- back to misc
            else
                if #st.major < 5 then table.insert(st.major, sk)
                elseif #st.minor < 5 then table.insert(st.minor, sk) end
            end
            show(pname)
            return true
        end
    end
    if fields.next then
        if st.page < 5 then st.page = st.page + 1 end
        show(pname)
        return true
    end
    if fields.back then
        if st.page > 1 then st.page = st.page - 1 end
        show(pname)
        return true
    end
    if fields.confirm then
        local race = R.races[st.race_idx]
        local variant = race.variants[st.variant_idx]
        local class = R.classes[st.class_idx]
        local sign = SIGNS.signs[st.sign_idx]
        local major, minor
        if class.id == "custom" then
            if #st.major ~= 5 or #st.minor ~= 5 then
                minetest.chat_send_player(pname, minetest.colorize("#ff8888",
                    "[Lumia] Sélectionne exactement 5 majeurs et 5 mineurs avant de confirmer."))
                show(pname)
                return true
            end
            major, minor = st.major, st.minor
        else
            major, minor = class.major, class.minor
        end
        local spec = (class.id == "custom") and SPECS[st.spec_idx] or class.spec
        lumia_chargen.finalize(player, race, variant, class, st.charname, major, minor, sign, spec)
        STATE[pname] = nil
        return true
    end
    if fields.quit then
        -- Joueur a tenté de fermer : on rouvre.
        if not lumia_chargen.is_done(pname) then
            minetest.after(0.2, function()
                if minetest.get_player_by_name(pname) then show(pname) end
            end)
        end
        return true
    end
end)
