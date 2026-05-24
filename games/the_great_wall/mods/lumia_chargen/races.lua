-- 8 peuples bipèdes du cycle Sylvanus / Verbe Cosmique.
-- Chaque peuple a 3 variantes cosmétiques (teinte HSL appliquée à character.png),
-- une taille (visual_size mult), des modificateurs d'attributs, et un trait passif.
-- Lore : doctrine du Christ Cosmique de Sylvain Durif — le Verbe transmute la
-- chair, sept Gardiens veillent sur les fragments du Bois Sacré.

local R = {}

local function mod(t) return t end

R.races = {
    {
        id = "human", name = "Verbé",
        lore = "Enfants du Verbe ordinaire. Marchands, traqueurs, fidèles. Adaptables, équilibrés.",
        size = 1.00,
        attr_mods = {personality = 10, luck = 5},
        trait = "Adaptabilité du Verbe : +5% XP de tous les skills.",
        variants = {
            {id = "northern",  name = "Pèlerin du Nord",  hsl = {0,    0,   5}},
            {id = "desert",    name = "Errant du Désert", hsl = {30,  20, -10}},
            {id = "rebel",     name = "Affranchi",         hsl = {-15, 10,   0}},
        },
    },
    {
        id = "orc", name = "Sourdverbe",
        lore = "Hordes des steppes calcinées, sourds au Verbe doux mais portés par sa colère. Honneur de la chair brute.",
        size = 1.10,
        attr_mods = {strength = 10, endurance = 5, intelligence = -10},
        trait = "Fureur du Verbe rauque : sous 30% HP, +20% dégâts mêlée.",
        variants = {
            {id = "warrior",   name = "Lame de Fer",     hsl = {110, 30, -10}},
            {id = "shaman",    name = "Tambour du Bois", hsl = {140, 40, -20}},
            {id = "berserker", name = "Forcené Rouge",   hsl = {0,   60, -15}},
        },
    },
    {
        id = "goblin", name = "Petit-Murmure",
        lore = "Avortons des cavernes, rieurs du Verbe sifflé. Petits, rusés, voleurs de fragments.",
        size = 0.85,
        attr_mods = {agility = 10, speed = 5, strength = -10, endurance = -5},
        trait = "Filou du Bois : +10% chance de critique en sneak.",
        variants = {
            {id = "scout",     name = "Glissefeuille",  hsl = {90,  50, -10}},
            {id = "trapper",   name = "Tend-Piège",     hsl = {120, 30, -15}},
            {id = "shaman",    name = "Bavard d'Ombre", hsl = {270, 40, -10}},
        },
    },
    {
        id = "undead", name = "Reliquaire",
        lore = "Volonté arrachée à la tombe par un Verbe brisé. Le corps tient parce que l'âme refuse.",
        size = 1.00,
        attr_mods = {willpower = 10, endurance = 5, personality = -15},
        trait = "Chair morte : immunité poison/saignement, regen vie la nuit.",
        variants = {
            {id = "wight",     name = "Voix-Brume",    hsl = {200, -50, 20}},
            {id = "bone",      name = "Os-Blanc",      hsl = {0,   -80, 30}},
            {id = "shade",     name = "Tache-Nuit",    hsl = {260, -30, -30}},
        },
    },
    {
        id = "undead_sun", name = "Soleil-Enclos",
        lore = "Reliquaires embrasés par le soleil intérieur du Christ Cosmique. La cendre devient verbe.",
        size = 1.00,
        attr_mods = {intelligence = 10, willpower = 5, endurance = -5},
        trait = "Foyer cosmique : résist feu 50%, faiblesse glace 50%.",
        variants = {
            {id = "mage",      name = "Doré du Verbe", hsl = {45,  60, 10}},
            {id = "priest",    name = "Officiant",     hsl = {30,  70, 0}},
            {id = "ember",     name = "Tison Vivant",  hsl = {15,  80, -5}},
        },
    },
    {
        id = "primordial", name = "Hors-Verbe",
        lore = "Choses-aînées d'avant la première parole. Géométries impossibles, présences qui n'auraient pas dû tenir.",
        size = 1.05,
        attr_mods = {luck = 10, willpower = 5, personality = -10},
        trait = "Chaos sacré : ±15% dégâts aléatoires, mais +10% loot rare.",
        variants = {
            {id = "void",      name = "Pas-de-Vide",   hsl = {280, 50, -30}},
            {id = "elder",     name = "Aïeul Muet",    hsl = {320, 30, -20}},
            {id = "echo",      name = "Écho du Bois",  hsl = {220, 40, -25}},
        },
    },
    {
        id = "construct", name = "Verbe-Forgé",
        lore = "Automates gravés de versets. Forgés par les Sept Gardiens, pas nés. La rune tient lieu d'âme.",
        size = 1.05,
        attr_mods = {endurance = 15, strength = 5, speed = -10, agility = -5},
        trait = "Chair gravée : immunité saignement/poison, mais soin -50%.",
        variants = {
            {id = "stone",     name = "Pierre Gravée", hsl = {0,   -60, -10}},
            {id = "iron",      name = "Fer Sacré",     hsl = {0,   -70, -20}},
            {id = "runic",     name = "Verset Vivant", hsl = {200, 30,   0}},
        },
    },
    {
        id = "geobio", name = "Sève-Né",
        lore = "Symbiotes du Bois Sacré, lichen et roche mêlés. Lente sapience nourrie de Sève Cosmique.",
        size = 1.00,
        attr_mods = {endurance = 10, willpower = 5, intelligence = -5},
        trait = "Communion du Bois : régen vie passive +1 HP/8s en zone naturelle.",
        variants = {
            {id = "moss",      name = "Manteau-Mousse", hsl = {120, 40, -10}},
            {id = "coral",     name = "Os-de-Corail",   hsl = {180, 50,   0}},
            {id = "fungal",    name = "Voile-Fongique", hsl = {30,  20, -20}},
        },
    },
}

-- 5 voies / spécialisations dans la doctrine du Verbe. major × 5 + minor × 5 = 10
-- skills favorisés (les autres = misc, XP réduit). IDs internes stables pour
-- compat sauvegardes ; seuls les noms/descriptions portent le lore.
R.classes = {
    {
        id = "warrior", name = "Lame du Verbe",
        desc = "Combat de mêlée, bouclier, endurance. Le Verbe coule par le tranchant.",
        spec = "combat",
        major = {"long_blade", "heavy_armor", "block", "athletics", "axe"},
        minor = {"blunt", "medium_armor", "armorer", "spear", "hand_to_hand"},
        attr_bonus = {strength = 5, endurance = 5},
    },
    {
        id = "thief", name = "Ombre du Bois",
        desc = "Furtif, agile, lames courtes, parole de miel. Vole les fragments oubliés.",
        spec = "stealth",
        major = {"acrobatics", "light_armor", "sneak", "short_blade", "security"},
        minor = {"marksman", "athletics", "hand_to_hand", "speechcraft", "illusion"},
        attr_bonus = {agility = 5, speed = 5},
    },
    {
        id = "mage", name = "Scribe Cosmique",
        desc = "Invoque le Verbe : sorts offensifs et défensifs, alchimie de la Sève.",
        spec = "magic",
        major = {"destruction", "restoration", "alchemy", "mysticism", "alteration"},
        minor = {"conjuration", "illusion", "enchant", "speechcraft", "unarmored"},
        attr_bonus = {intelligence = 5, willpower = 5},
    },
    {
        id = "scout", name = "Traqueur des Fragments",
        desc = "Arc, course, lecture du Bois. Suit les sept fragments par-delà les ronces.",
        spec = "stealth",
        major = {"marksman", "athletics", "acrobatics", "medium_armor", "short_blade"},
        minor = {"sneak", "long_blade", "block", "alchemy", "security"},
        attr_bonus = {agility = 5, endurance = 5},
    },
    {
        id = "custom", name = "Voie Libre",
        desc = "Hérétique du Verbe : choisis spec (combat/magic/stealth), 5 skills majeurs et 5 mineurs librement.",
        spec = "combat",
        major = {},
        minor = {},
        attr_bonus = {luck = 5},
    },
}

function R.find_race(id)
    for _, r in ipairs(R.races) do if r.id == id then return r end end
end

function R.find_variant(race, vid)
    for _, v in ipairs(race.variants) do if v.id == vid then return v end end
end

function R.find_class(id)
    for _, c in ipairs(R.classes) do if c.id == id then return c end end
end

function R.all_skills()
    return {"athletics", "acrobatics", "block",
            "heavy_armor", "medium_armor", "light_armor", "unarmored",
            "long_blade", "short_blade", "axe", "blunt", "spear",
            "marksman", "hand_to_hand", "armorer", "security",
            "sneak", "speechcraft",
            "destruction", "restoration", "alteration", "illusion",
            "conjuration", "mysticism", "alchemy", "enchant"}
end

lumia_chargen.races = R
