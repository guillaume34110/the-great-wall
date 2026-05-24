-- tgw_pipeline : reçoit les capturés, les téléporte au bout de la map,
-- RNG 50% renvoie une nouvelle entité du même type côté ennemi.

local S = core.get_translator("tgw_pipeline")
tgw_pipeline = {}
tgw_pipeline.S = S

local cfg = tgw_core.config

-- send(invader_lua_entity, capturer_name)
function tgw_pipeline.send(invader, capturer_name)
    if not invader or not invader.object then return end
    local type_name = invader._tgw_type
    local wave_idx  = invader._wave_idx or 1
    local exit_pos  = tgw_map.get_pipeline_exit()

    -- Téléport visuel à la sortie, puis attente
    invader.object:set_pos(exit_pos)
    invader.object:set_velocity({ x = 0, y = 0, z = 0 })

    core.after(3.0, function()
        if not invader or not invader.object then return end
        invader.object:remove()

        if math.random(100) <= cfg.pipeline_return_pct then
            -- Re-spawn même type côté ennemi
            local p = tgw_map.random_enemy_spawn()
            local new_obj = tgw_invader.spawn(type_name, p, wave_idx)
            tgw_core.emit("invader_returned", {
                type = type_name,
                wave = wave_idx,
                pos = p,
                obj = new_obj,
            })
        end
    end)
end

core.log("action", "[tgw_pipeline] loaded (return " .. cfg.pipeline_return_pct .. "%)")
