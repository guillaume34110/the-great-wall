-- tgw_trump_skin : skin Trump (placeholder = character.png colorisé orange)
-- appliqué à tous les joueurs sur join/respawn.

local S = core.get_translator("tgw_trump_skin")
tgw_trump_skin = {}
tgw_trump_skin.S = S

-- Placeholder : tint orange Trump. Remplacer plus tard par character_trump.png
-- (sprite_gen ou texture custom 64×32).
local TRUMP_TEXTURE = "character.png^[colorize:#ffa040:120"

function tgw_trump_skin.apply(player)
    if not player or not player:is_player() then return end
    player_api.set_textures(player, { TRUMP_TEXTURE })
end

core.register_on_joinplayer(function(player)
    core.after(0.5, function()
        if player and player:is_player() then tgw_trump_skin.apply(player) end
    end)
end)

core.register_on_respawnplayer(function(player)
    core.after(0.5, function()
        if player and player:is_player() then tgw_trump_skin.apply(player) end
    end)
end)

core.log("action", "[tgw_trump_skin] loaded")
