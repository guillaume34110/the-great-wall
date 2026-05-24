-- tgw_reset : soft-reset auto sur DEFEAT/VICTORY.
-- Pas de wipe disque (HoF préservé via fichier hors worldpath).
-- Reset = clear entities + reset wallets + rebuild mur+maison + LOBBY.

local S = core.get_translator("tgw_reset")
tgw_reset = {}
tgw_reset.S = S

local RESET_DELAY = 15  -- secondes après defeat/victory avant reset

local pending = false

-- ---------------------------------------------------------------------------
-- Wipe joueurs (perso wallet + inv)
-- ---------------------------------------------------------------------------

local function wipe_player(p)
    if not p or not p:is_player() then return end
    local meta = p:get_meta()
    meta:set_int("tgw_pers_$", 0)
    p:set_hp(20)
    p:set_breath(11)
    local inv = p:get_inventory()
    if inv then
        inv:set_list("main", {})
        inv:set_list("craft", {})
    end
    p:set_pos(tgw_map.get_player_spawn())
end

-- ---------------------------------------------------------------------------
-- Soft reset pipeline
-- ---------------------------------------------------------------------------

function tgw_reset.run(reason)
    if pending then return end
    pending = true
    core.chat_send_all(S("World will reset in @1s (@2).", RESET_DELAY, reason or "?"))

    core.after(RESET_DELAY, function()
        core.log("action", "[tgw_reset] performing soft reset (" .. (reason or "?") .. ")")

        -- 1. Emit world_reset → tgw_economy/wall/house/shop remettent leurs flags
        tgw_core.emit("world_reset", {})

        -- 2. Clear toutes les entités (invaders, items au sol, etc.)
        core.after(0.5, function()
            for _, obj in ipairs(core.get_objects_inside_radius({ x = 0, y = 0, z = 0 }, 2000)) do
                if obj and not obj:is_player() then
                    obj:remove()
                end
            end

            -- 3. Reset joueurs (wallet perso + inv)
            for _, p in ipairs(core.get_connected_players()) do
                wipe_player(p)
            end

            -- 4. Rebuild mur + maison + comptoir shop
            if tgw_wall  and tgw_wall.build  then tgw_wall.build(true)  end
            if tgw_house and tgw_house.build then tgw_house.build(true) end
            if tgw_shop  and tgw_shop.place_counter then tgw_shop.place_counter(true) end

            -- 5. Re-loadout joueurs
            core.after(1.0, function()
                if tgw_combat and tgw_combat.give_loadout then
                    for _, p in ipairs(core.get_connected_players()) do
                        tgw_combat.give_loadout(p)
                    end
                end

                -- 6. Retour LOBBY
                tgw_core.set_state(tgw_core.STATE.LOBBY)
                pending = false
                core.chat_send_all(S("Lobby ready. Press START to begin a new run."))
            end)
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

tgw_core.on("run_won",  function() tgw_reset.run("victory") end)
tgw_core.on("run_lost", function() tgw_reset.run("defeat")  end)

core.log("action", "[tgw_reset] loaded (delay=" .. RESET_DELAY .. "s)")
