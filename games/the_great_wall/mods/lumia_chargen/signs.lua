-- Signes du Verbe : 13 constellations sous lesquelles naissent les âmes du
-- cycle de Sylvanus. Sept Gardiens majeurs + six étoiles-errantes.
-- Bonus passifs : attributs, skills, magicka, regen, résistances.

local S = {}

S.signs = {
    {
        id = "warrior", name = "Le Gardien-Lame",
        lore = "Étoile rouge du premier Gardien. Mort glorieuse, vie ardente, le Verbe par le tranchant.",
        attr_mods = {strength = 5, endurance = 5},
        skill_mods = {long_blade = 5, axe = 5, blunt = 5},
    },
    {
        id = "lady", name = "La Vierge du Bois",
        lore = "Grâce et résilience. Bénédiction des clairières du Christ Cosmique.",
        attr_mods = {endurance = 10, personality = 5},
    },
    {
        id = "lord", name = "Le Roi-Pierre",
        lore = "Chair gravée du Verbe ancien : régénération, mais le feu profane y mord.",
        regen_hp = 0.4,  -- HP/sec
        resist_fire = -0.5,
    },
    {
        id = "mage", name = "Le Scribe Étoilé",
        lore = "Fontaine intarissable du Verbe. La main court plus vite que le souffle.",
        magicka_mult = 1.5,
        attr_mods = {intelligence = 5},
    },
    {
        id = "apprentice", name = "Le Novice du Verbe",
        lore = "Verbe débordant, mais chair tendre face aux sortilèges adverses.",
        magicka_mult = 2.0,
        resist_magic = -0.5,
    },
    {
        id = "atronach", name = "Le Vase Cosmique",
        lore = "Stase du Verbe : pas de regen mana, mais absorbe 50% des sorts reçus.",
        magicka_mult = 2.0,
        regen_magicka = -1.0,  -- annule
        absorb_magic = 0.5,
    },
    {
        id = "thief", name = "Le Glaneur",
        lore = "Doigts agiles, esprit vif. Récolte les fragments tombés du Bois.",
        attr_mods = {agility = 5, speed = 5, luck = 10},
    },
    {
        id = "shadow", name = "L'Ombre du Bois",
        lore = "Le Verbe se tait : invisibilité fugace une fois par jour (placeholder).",
        skill_mods = {sneak = 10},
    },
    {
        id = "lover", name = "Le Souffle-Cœur",
        lore = "Le Verbe murmure et fige : touche unique paralyse l'ennemi 5s (placeholder).",
        attr_mods = {agility = 25},
        attr_drain = {fatigue = 0},
    },
    {
        id = "steed", name = "Le Cerf-Étoile",
        lore = "Monture du Christ Cosmique : vitesse, endurance, pas de fatigue à la course.",
        attr_mods = {speed = 25},
        sprint_no_drain = true,
    },
    {
        id = "ritual", name = "Le Cercle Cosmique",
        lore = "Rite du Verbe : soin majeur disponible (placeholder), repousse les Reliquaires hostiles.",
        skill_mods = {restoration = 10},
    },
    {
        id = "serpent", name = "L'Usurpateur",
        lore = "Étoile errante, langue fourchue contre le Verbe. Pas de bonus pur, mais venin (placeholder) sur attaque.",
        attr_mods = {luck = 5},
    },
    {
        id = "tower", name = "La Tour-Vigie",
        lore = "Œil du septième Gardien : vision perçante des serrures et des coffres.",
        skill_mods = {security = 10},
    },
}

function S.find(id)
    for _, sg in ipairs(S.signs) do if sg.id == id then return sg end end
end

lumia_chargen.signs = S
