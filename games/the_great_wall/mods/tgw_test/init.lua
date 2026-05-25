-- tgw_test : smoke tests post-load. Pas de player requis.
-- Log : [TGW_TEST] PASS/FAIL <name>  → grep "TGW_TEST" pour résultats.

local results = { pass = 0, fail = 0 }

local function check(name, cond, detail)
    if cond then
        results.pass = results.pass + 1
        core.log("action", "[TGW_TEST] PASS " .. name)
    else
        results.fail = results.fail + 1
        core.log("error", "[TGW_TEST] FAIL " .. name ..
            (detail and (" :: " .. tostring(detail)) or ""))
    end
end

local function approx(a, b, eps)
    return math.abs(a - b) < (eps or 0.01)
end

core.after(3.0, function()
    core.log("action", "[TGW_TEST] === START ===")

    -- ---------------------------------------------------------------------
    -- Bloc 9 : invader types ranged
    -- ---------------------------------------------------------------------
    local expected_types = {
        "runner", "tank", "digger",
        "shooter", "sniper",
        "boss_titan", "boss_gunner", "boss_summoner",
    }
    for _, t in ipairs(expected_types) do
        check("invader_type:" .. t, tgw_invader.TYPES[t] ~= nil)
    end
    check("invader.shooter.attack_kind=ranged",
        tgw_invader.TYPES.shooter.attack_kind == "ranged")
    check("invader.sniper.range=50",
        tgw_invader.TYPES.sniper.ranged_range == 50)

    -- ---------------------------------------------------------------------
    -- Bloc 10 : boss rotation + scale
    -- ---------------------------------------------------------------------
    check("boss_for_wave(99) nil",     tgw_invader.boss_for_wave(99)  == nil)
    check("boss_for_wave(100)=titan",  tgw_invader.boss_for_wave(100) == "boss_titan")
    check("boss_for_wave(105) nil",    tgw_invader.boss_for_wave(105) == nil)
    check("boss_for_wave(110)=gunner", tgw_invader.boss_for_wave(110) == "boss_gunner")
    check("boss_for_wave(120)=summ",   tgw_invader.boss_for_wave(120) == "boss_summoner")
    check("boss_for_wave(130)=titan",  tgw_invader.boss_for_wave(130) == "boss_titan")
    check("boss_for_wave(200)=gunner", tgw_invader.boss_for_wave(200) == "boss_gunner")
    check("boss_scale(100)=1.0",  approx(tgw_invader.boss_scale(100), 1.0))
    check("boss_scale(200)>3.5",  tgw_invader.boss_scale(200) > 3.5)

    -- ---------------------------------------------------------------------
    -- Bloc 8 : weapons + accessories registry
    -- ---------------------------------------------------------------------
    local expected_weapons = { "bat", "pistol", "shotgun", "ar", "sniper", "minigun" }
    for _, w in ipairs(expected_weapons) do
        check("weapon:" .. w, tgw_combat.weapons[w] ~= nil)
        check("weapon_item:" .. w,
            core.registered_items["tgw_combat:" .. w] ~= nil)
    end

    check("pistol.mag_size=12",  tgw_combat.weapons.pistol.mag_size  == 12)
    check("shotgun.mag_size=6",  tgw_combat.weapons.shotgun.mag_size == 6)
    check("ar.mag_size=30",      tgw_combat.weapons.ar.mag_size      == 30)
    check("sniper.mag_size=5",   tgw_combat.weapons.sniper.mag_size  == 5)
    check("minigun.mag_size=100",tgw_combat.weapons.minigun.mag_size == 100)
    check("bat.no_mag_size",     tgw_combat.weapons.bat.mag_size     == nil)

    local expected_accs = {
        "ext_barrel", "supp", "ext_mag", "drum",
        "red_dot", "scope", "foregrip", "tac_grip",
    }
    for _, a in ipairs(expected_accs) do
        check("accessory:" .. a, tgw_combat.accessories[a] ~= nil)
        check("accessory_item:" .. a,
            core.registered_items["tgw_combat:acc_" .. a] ~= nil)
    end

    -- ---------------------------------------------------------------------
    -- Bloc 8a : XP scaling via _effective sur ItemStack synthétique
    -- ---------------------------------------------------------------------
    local def = tgw_combat.weapons.pistol
    local s0 = ItemStack("tgw_combat:pistol")
    local e0 = tgw_combat._effective(def, s0)
    check("pistol.eff.dmg=10 (lvl0)",  e0.damage   == 10)
    check("pistol.eff.cd=0.45 (lvl0)", approx(e0.cooldown, 0.45))
    check("pistol.eff.range=35",       e0.range    == 35)
    check("pistol.eff.mag=12",         e0.mag_size == 12)

    -- XP enough for lvl 3 (≥ 50*3^1.6 = ~466 → cumulé : xp_needed(3))
    local s3 = ItemStack("tgw_combat:pistol")
    s3:get_meta():set_int("xp", 500)
    local e3 = tgw_combat._effective(def, s3)
    check("pistol.eff.dmg lvl3 +30%",  e3.damage   >= 13)
    check("pistol.eff.cd lvl3 -12%",   e3.cooldown < 0.45)

    -- ---------------------------------------------------------------------
    -- Bloc 8c : accessoires appliqués via _effective
    -- ---------------------------------------------------------------------
    local sa = ItemStack("tgw_combat:pistol")
    sa:get_meta():set_string("acc_barrel", "ext_barrel")  -- +30% rng, +10% dmg
    sa:get_meta():set_string("acc_mag",    "drum")        -- +100% mag, +30% reload
    sa:get_meta():set_string("acc_sight",  "red_dot")     -- -40% spread (no-op pistol)
    sa:get_meta():set_string("acc_grip",   "foregrip")    -- -25% cd
    local ea = tgw_combat._effective(def, sa)
    check("acc.dmg pistol +10% =11",    ea.damage   == 11)
    check("acc.range +30% =45.5",       approx(ea.range, 45.5))
    check("acc.mag x2 =24",             ea.mag_size == 24)
    check("acc.cd -25% =0.3375",        approx(ea.cooldown, 0.45 * 0.75))
    check("acc.reload_mul =1.3",        approx(ea.reload_mul or 1, 1.3))

    -- Combo XP + accessoires : dmg cumulé
    local sc = ItemStack("tgw_combat:pistol")
    sc:get_meta():set_int("xp", 500)                    -- lvl 3 → dmg 13
    sc:get_meta():set_string("acc_barrel", "ext_barrel")-- +10% → 14.3 → 14
    local ec = tgw_combat._effective(def, sc)
    check("combo.dmg lvl3+barrel ~14",  ec.damage >= 14 and ec.damage <= 15)

    -- ---------------------------------------------------------------------
    -- Bloc 11 : thèmes (via inspection THEMES si exposé, sinon skip)
    -- Note : pick_theme local, on teste via spawn_wave en mock ?
    -- → on vérifie au moins l'enum d'IDs prévus en regardant le source.
    -- ---------------------------------------------------------------------
    check("waves loaded", type(tgw_waves) == "table")
    check("waves.get_current()", tgw_waves.get_current() == 0)

    -- ---------------------------------------------------------------------
    -- Done
    -- ---------------------------------------------------------------------
    core.log("action", "[TGW_TEST] === DONE : " ..
        results.pass .. " PASS / " .. results.fail .. " FAIL ===")
end)
