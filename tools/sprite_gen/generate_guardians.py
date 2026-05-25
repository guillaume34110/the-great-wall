#!/usr/bin/env python3
"""Génère 8 skins joueur 64×32 (mc_humanoid layout) pour tgw_trump_skin.
Chaque gardien a sa propre silhouette : coiffure, costume, accessoires.
"""
from __future__ import annotations
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT  = ROOT / "games/the_great_wall/mods/tgw_trump_skin/textures"
CLI  = [sys.executable, "-m", "sprite_gen", "--kind", "uv_atlas",
        "--out", str(OUT)]

# ---------------------------------------------------------------------------
# Convention palette (chars partagés)
#   . transparent     S skin base    s skin shadow    l skin highlight
#   H hair main       h hair light   d hair dark      b beard
#   E eye             M mouth
#   U cloth main      u cloth dark   A accent         a accent dark
#   G gold            P pants        B boots          X armor metal
# ---------------------------------------------------------------------------

# Templates génériques pour faces peu visibles (back/bottom).
def solid(w, h, c):
    return [c * w for _ in range(h)]

# Torso back générique : juste la couleur principale + ceinture.
def torso_back(c_main="U", c_belt="u"):
    rows = [c_main * 8] * 6 + [c_main + c_belt * 6 + c_main, c_belt * 8] + [c_main * 8] * 4
    return rows

def torso_side(c_main="U", c_belt="u"):
    rows = [c_main * 4] * 6 + [c_main + c_belt * 2 + c_main, c_belt * 4] + [c_main * 4] * 4
    return rows

def arm_back(c_main="U", c_cuff="u", c_hand="S"):
    return [c_main * 4] * 9 + [c_cuff * 4] + [c_hand * 4] * 2

def leg_back(c_pants="P", c_boot="B"):
    return [c_pants * 4] * 10 + [c_boot * 4] * 2

# ---------------------------------------------------------------------------
# Donald Trump : comb-over blond, peau orangée, costume bleu + cravate rouge
# ---------------------------------------------------------------------------
TRUMP = {
    "palette": {
        ".": None,
        "S": "#e8b070", "s": "#c8884a", "l": "#f8c890",  # peau orangée
        "H": "#f0d050", "h": "#fff0a0", "d": "#b89020",  # blond doré
        "E": "#2a4080", "M": "#883030",
        "U": "#1a2050", "u": "#0e1430",                  # costume bleu marine
        "A": "#c01020", "a": "#700810",                  # cravate rouge
        "P": "#1a2050", "B": "#1a1a1a",
    },
    "regions": {
        "head_top":    ["dHHHHHHd",
                        "HhhhhhhH",
                        "HhhhhhhH",
                        "HhhhhhhH",
                        "HhhhhhhH",
                        "HhhhhhhH",
                        "HhhhhhhH",
                        "dHHHHHHd"],
        "head_bottom": [".sssssS.",
                        "ssssssss",
                        "ssssMMss",
                        "ssMMMMss",
                        "ssssssss",
                        "ssssssss",
                        "ssssssss",
                        ".ssssss."],
        "head_front":  ["dHHHHHHd",  # comb-over qui dépasse
                        "HhhhhhhH",
                        "SSSSSSSS",  # front bronzé
                        "SEEsSsEE",  # yeux bleus plissés
                        "SSSSlSSS",  # nez clair
                        "sSMMMMSs",  # bouche pincée
                        "SSssssSS",  # menton
                        ".SSSSSS."],
        "head_back":   ["dHHHHHHd",
                        "HhhhhhhH",
                        "HhhhhhhH",
                        "HhhhhhhH",
                        "HhhhhhhH",
                        "HhhhhhhH",
                        "SSSSSSSS",
                        ".ssssss."],
        "head_right":  [".HHHHHHd",
                        "HhhhhhhH",
                        "HhhSSSSS",
                        "SHhsSSSS",
                        "SSHhSSSS",
                        "SssHhSSS",
                        "sssssSSS",
                        ".ssssss."],
        "head_left":   ["dHHHHHH.",
                        "HhhhhhhH",
                        "SSSSShhH",
                        "SSSSSshH",
                        "SSSShHSS",  # mèche peignée vers la gauche
                        "SSShhSss",
                        "SSSssss.",
                        ".ssssss."],
        "torso_top":   ["dHHHHHHd",  # nuque + col
                        "uUUUUUUu",
                        "uUUAAUUu",
                        "uuuAAuuu"],
        "torso_bottom":["uuuuuuuu",
                        "uPPPPPPu",
                        "uPPPPPPu",
                        "uuuuuuuu"],
        "torso_front": ["uUUUUUUu",  # costume avec revers
                        "UuAAAAuU",  # col blanc/cravate visible
                        "UAuAAuAU",
                        "UAuAAuAU",
                        "UUuAAuUU",
                        "UUuAAuUU",
                        "UUuAAuUU",
                        "UUuAAuUU",
                        "UuuAAuuU",
                        "uuuauauu",
                        "UUUUUUUU",
                        "uUUUUUUu"],
        "torso_back":  torso_back("U", "u"),
        "torso_right": torso_side("U", "u"),
        "torso_left":  torso_side("U", "u"),
        "arm_r_top":   ["uUUUu...",   # 4 col, padding ignoré
                        "UUUU....",
                        "UUUU....",
                        "uUUUu..."][:4] and ["UUUU"]*4,
        "arm_r_bottom":["SSSS"]*4,
        "arm_r_right": ["UUUU"]*9 + ["uuuu"] + ["SSSS","sssS"],
        "arm_r_front": ["UUUU"]*8 + ["UUUU", "uuuu", "SSSS", "SsSS"],
        "arm_r_left":  ["UUUU"]*9 + ["uuuu"] + ["SSSS","SsssS"][:1] + ["SSSS"],
        "arm_r_back":  arm_back("U", "u", "S"),
        "leg_r_top":   ["uuuu","uPPu","uPPu","uuuu"],
        "leg_r_bottom":["BBBB"]*4,
        "leg_r_right": ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_front": ["PPPP"]*9 + ["uuuu", "BBBB", "BBBB"],
        "leg_r_left":  ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_back":  leg_back("P", "B"),
    },
}

# ---------------------------------------------------------------------------
# Qin Shi Huang : empereur, robe rouge brodée or, longue barbe noire, couronne
# ---------------------------------------------------------------------------
QIN = {
    "palette": {
        ".": None,
        "S": "#d8a878", "s": "#a87848", "l": "#e8c098",
        "H": "#1a1a1a", "h": "#3a2a14", "d": "#0a0a0a",
        "b": "#1a1408", "E": "#3a2010", "M": "#6a2020",
        "U": "#7a0a14", "u": "#3a0608",                  # rouge impérial
        "A": "#d8b020", "a": "#a08010",                  # broderies or
        "G": "#f0d020",                                  # couronne or
        "P": "#3a0608", "B": "#2a1408",
    },
    "regions": {
        "head_top":    ["GGGGGGGG",  # couronne dorée
                        "GHHHHHHG",
                        "GHHHHHHG",
                        "GHHHHHHG",
                        "GHHHHHHG",
                        "GHHHHHHG",
                        "GHHHHHHG",
                        "GGGGGGGG"],
        "head_bottom": [".bbbbbb.",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        ".bbbbbb."],
        "head_front":  ["GGGGGGGG",  # couronne or
                        "HHHHHHHH",  # cheveux noirs
                        "HSSSSSSH",
                        "HSEssEsH",
                        "HsSlSsSH",
                        "Sbbbbbb.",  # moustache
                        "bbMMMMbb",  # bouche dans barbe
                        ".bbbbbb."],
        "head_back":   ["GGGGGGGG",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        ".bbbbbb."],
        "head_right":  ["GGGGGGGG",
                        "HHHHHHHH",
                        "HHHSSSSS",
                        "HHsSSSSS",
                        "HHsSSSSS",
                        "Hbbbbbbb",
                        "bbbbbbbb",
                        ".bbbbbb."],
        "head_left":   ["GGGGGGGG",
                        "HHHHHHHH",
                        "SSSSSHHH",
                        "SSSSSsHH",
                        "SSSSSsHH",
                        "bbbbbbbH",
                        "bbbbbbbb",
                        ".bbbbbb."],
        "torso_top":   ["bbbbbbbb",
                        "UAAAAAAU",
                        "UAAAAAAU",
                        "uAAAAAAu"],
        "torso_bottom":["uuuuuuuu",
                        "uPPPPPPu",
                        "uPPPPPPu",
                        "uuuuuuuu"],
        "torso_front": ["UAAAAAAU",  # col brodé or
                        "UAaaaaAU",
                        "UAaUUaAU",
                        "UaUAAUaU",  # broderie centrale
                        "UaUAAUaU",
                        "UaUAAUaU",
                        "UAUAAUAU",
                        "UAaUUaAU",
                        "UAaaaaAU",
                        "uaaaaaaau"[:8],
                        "UAAAAAAU",
                        "uUUUUUUu"],
        "torso_back":  torso_back("U", "u"),
        "torso_right": torso_side("U", "u"),
        "torso_left":  torso_side("U", "u"),
        "arm_r_top":   ["UUUU"]*4,
        "arm_r_bottom":["SSSS"]*4,
        "arm_r_right": ["UUUU"]*9 + ["AAAA"] + ["SSSS"]*2,
        "arm_r_front": ["UUUU"]*8 + ["UAAU", "AAAA", "SSSS", "SSSS"],
        "arm_r_left":  ["UUUU"]*9 + ["AAAA"] + ["SSSS"]*2,
        "arm_r_back":  arm_back("U", "A", "S"),
        "leg_r_top":   ["uuuu","uPPu","uPPu","uuuu"],
        "leg_r_bottom":["BBBB"]*4,
        "leg_r_right": ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_front": ["PPPP"]*9 + ["uuuu", "BBBB", "BBBB"],
        "leg_r_left":  ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_back":  leg_back("P", "B"),
    },
}

# ---------------------------------------------------------------------------
# Hadrien : couronne de laurier, barbe, cuirasse romaine rouge + lanières
# ---------------------------------------------------------------------------
HADRIAN = {
    "palette": {
        ".": None,
        "S": "#e8c098", "s": "#b89068", "l": "#f0d0a8",
        "H": "#3a2010", "h": "#5a3a1c", "d": "#1a0a04",
        "b": "#2a1408", "E": "#2a1408", "M": "#883030",
        "U": "#c81020", "u": "#7a0810",                  # tunique rouge
        "A": "#e0b830", "a": "#a08020",                  # bandes or
        "G": "#3aa830",                                  # laurier vert
        "P": "#b08850", "B": "#5a3a1c",                  # jupe cuir bronze
    },
    "regions": {
        "head_top":    [".GGddGG.",   # couronne laurier
                        "GhhHHhhG",
                        "GhHHHHhG",
                        "dHHHHHHd",
                        "dHHHHHHd",
                        "GhHHHHhG",
                        "GhhHHhhG",
                        ".GGddGG."],
        "head_bottom": [".bbbbbb.",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        ".bbbbbb."],
        "head_front":  [".GdHHdG.",   # laurier + cheveux
                        "GHHHHHHG",
                        "HSSSSSSH",
                        "HsEsSsEs",
                        "HSSSlSSH",
                        "HSbbbbbS",   # début barbe
                        "SbMMMMbS",
                        ".bbbbbb."],
        "head_back":   [".GdHHdG.",
                        "GHHHHHHG",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        ".bbbbbb."],
        "head_right":  [".GdHHdG.",
                        "GHHHHHHG",
                        "HHHHSSSS",
                        "HHHsSSSS",
                        "HHsSSSSS",
                        "HsbbbbbS",
                        "bbbbbbbb",
                        ".bbbbbb."],
        "head_left":   [".GdHHdG.",
                        "GHHHHHHG",
                        "SSSSHHHH",
                        "SSSSsHHH",
                        "SSSSSsHH",
                        "SbbbbbsH",
                        "bbbbbbbb",
                        ".bbbbbb."],
        "torso_top":   ["bbbbbbbb",
                        "UAAAAAAU",
                        "AaaUUaaA",
                        "UuuuuuuU"],
        "torso_bottom":["uuuuuuuu",
                        "uPPPPPPu",
                        "uPPPPPPu",
                        "uuuuuuuu"],
        "torso_front": ["UAAAAAAU",   # col cuirasse
                        "AaaUUaaA",
                        "UUuUUuUU",
                        "UAUUUUAU",   # médaillon central
                        "UAaAAaAU",
                        "UAaAAaAU",   # bandes pectorales
                        "UAUUUUAU",
                        "UUuUUuUU",
                        "UUUUUUUU",
                        "AAAAAAAA",   # ceinture or
                        "aPaPaPaP",   # lanières
                        "PPPPPPPP"],
        "torso_back":  torso_back("U", "A"),
        "torso_right": torso_side("U", "A"),
        "torso_left":  torso_side("U", "A"),
        "arm_r_top":   ["UUUU"]*4,
        "arm_r_bottom":["SSSS"]*4,
        "arm_r_right": ["UUUU"]*6 + ["AAAA"] + ["SSSS"]*3 + ["BBBB"]*2,
        "arm_r_front": ["UUUU"]*6 + ["AAAA", "SSSS", "SsSS", "SSSS", "BBBB", "BBBB"],
        "arm_r_left":  ["UUUU"]*6 + ["AAAA"] + ["SSSS"]*3 + ["BBBB"]*2,
        "arm_r_back":  ["UUUU"]*6 + ["AAAA"] + ["SSSS"]*3 + ["BBBB"]*2,
        "leg_r_top":   ["aaaa","aPPa","aPPa","aaaa"],
        "leg_r_bottom":["BBBB"]*4,
        "leg_r_right": ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_front": ["aPaP", "PaPa", "aPaP",        # frange jupe cuir
                        "PPPP","PPPP","PPPP","PPPP","PPPP","PPPP",
                        "aaaa", "BBBB","BBBB"],
        "leg_r_left":  ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_back":  leg_back("P", "B"),
    },
}

# ---------------------------------------------------------------------------
# Vauban : perruque blanche poudrée, tricorne, justaucorps bleu + boutons or
# ---------------------------------------------------------------------------
VAUBAN = {
    "palette": {
        ".": None,
        "S": "#e8c098", "s": "#b89068", "l": "#f0d8b8",
        "H": "#f0e8d8", "h": "#fff8e8", "d": "#a89880",  # perruque crème
        "E": "#2a4060", "M": "#883040",
        "U": "#1a3068", "u": "#0e1840",                  # bleu roi
        "A": "#f0c850", "a": "#a08020",                  # boutons or
        "G": "#2a1a0e",                                  # tricorne noir
        "P": "#80654a", "B": "#1a0a04",
    },
    "regions": {
        "head_top":    ["GGGGGGGG",   # tricorne aplati vu de haut
                        "GGGGGGGG",
                        "GGHHHHGG",
                        "GHhhhhHG",
                        "GHhhhhHG",
                        "GGHHHHGG",
                        "GGGGGGGG",
                        "GGGGGGGG"],
        "head_bottom": [".SSSSSS.",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        ".SSSSSS."],
        "head_front":  ["GGGGGGGG",   # bord tricorne
                        "HHHHHHHH",   # perruque front
                        "HSSSSSSH",
                        "HSEsSEsH",
                        "HSSSlSSH",
                        "HSSSSSSH",
                        "HSSMMSSH",
                        "HhssshhH"],  # rouleaux perruque
        "head_back":   ["GGGGGGGG",
                        "HHHHHHHH",
                        "HhhhhhhH",
                        "HhHHHHhH",
                        "HhHHHHhH",
                        "HhhhhhhH",
                        "HHHHHHHH",
                        "HhhhhhhH"],
        "head_right":  ["GGGGGGGG",
                        "HHHHHHHH",
                        "HHHHSSSS",
                        "HHHhsSSS",
                        "HHhhSSSS",
                        "HhhhSSSS",
                        "hhhhsSSS",
                        "hHhhssss"],
        "head_left":   ["GGGGGGGG",
                        "HHHHHHHH",
                        "SSSSHHHH",
                        "SSSshHHH",
                        "SSSShhHH",
                        "SSSShhhH",
                        "SSSshhhh",
                        "ssshhHhh"],
        "torso_top":   ["HHHHHHHH",   # rouleaux perruque sur épaules
                        "UAAAAAAU",
                        "UUUUUUUU",
                        "uuuuuuuu"],
        "torso_bottom":["uuuuuuuu",
                        "uPPPPPPu",
                        "uPPPPPPu",
                        "uuuuuuuu"],
        "torso_front": ["UAAAAAAU",   # col blanc + boutons or
                        "UAAAAAAU",
                        "UAuAAuAU",
                        "UAuAAuAU",
                        "UAuAAuAU",
                        "UAuAAuAU",
                        "UAuAAuAU",
                        "UAuAAuAU",
                        "UAuAAuAU",
                        "uaaaaaaau"[:8],
                        "UUUUUUUU",
                        "uUUUUUUu"],
        "torso_back":  torso_back("U", "u"),
        "torso_right": torso_side("U", "A"),
        "torso_left":  torso_side("U", "A"),
        "arm_r_top":   ["UUUU"]*4,
        "arm_r_bottom":["SSSS"]*4,
        "arm_r_right": ["UUUU"]*8 + ["AAAA"] + ["uuuu"] + ["SSSS"]*2,
        "arm_r_front": ["UUUU"]*8 + ["AAAA", "uuuu", "SSSS", "SsSS"],
        "arm_r_left":  ["UUUU"]*8 + ["AAAA"] + ["uuuu"] + ["SSSS"]*2,
        "arm_r_back":  ["UUUU"]*8 + ["AAAA"] + ["uuuu"] + ["SSSS"]*2,
        "leg_r_top":   ["uuuu","uPPu","uPPu","uuuu"],
        "leg_r_bottom":["BBBB"]*4,
        "leg_r_right": ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_front": ["PPPP"]*9 + ["uuuu", "BBBB", "BBBB"],
        "leg_r_left":  ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_back":  leg_back("P", "B"),
    },
}

# ---------------------------------------------------------------------------
# Jon Snow : capuche relevée, barbe brune, fourrure noire sur épaules
# ---------------------------------------------------------------------------
JON = {
    "palette": {
        ".": None,
        "S": "#d8b890", "s": "#a88860", "l": "#e8c8a0",
        "H": "#2a1a14", "h": "#4a2a1c", "d": "#1a0a08",
        "b": "#3a1a10", "E": "#3a4a3a", "M": "#5a3030",
        "U": "#1a1a1a", "u": "#0a0a0a",                  # noir Garde de Nuit
        "A": "#3a2a1a", "a": "#1a0e08",                  # fourrure brune
        "P": "#1a1410", "B": "#0e0a08",
    },
    "regions": {
        "head_top":    ["uuuuuuuu",   # capuche au sommet
                        "uuuuuuuu",
                        "uHHHHHHu",
                        "uHhhhhHu",
                        "uHhhhhHu",
                        "uHHHHHHu",
                        "uuuuuuuu",
                        "uuuuuuuu"],
        "head_bottom": [".bbbbbb.",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        ".bbbbbb."],
        "head_front":  ["uuuuuuuu",   # bord capuche
                        "uHHHHHHu",   # cheveux dans l'ombre
                        "uSSSSSSu",
                        "uSEssEsu",
                        "uSSSlSSu",
                        "ubbbbbbu",
                        "ubMMMMbu",
                        ".bbbbbb."],
        "head_back":   ["uuuuuuuu",
                        "uHHHHHHu",
                        "uHHHHHHu",
                        "uHHHHHHu",
                        "uHHHHHHu",
                        "uHHHHHHu",
                        "uHHHHHHu",
                        ".bbbbbb."],
        "head_right":  ["uuuuuuuu",
                        "uHHHHHHH",
                        "uHHHSSSS",
                        "uHHsSSSS",
                        "uHsSSSSS",
                        "ubbbbbbS",
                        "bbbbbbbb",
                        ".bbbbbb."],
        "head_left":   ["uuuuuuuu",
                        "HHHHHHHu",
                        "SSSSHHHu",
                        "SSSSsHHu",
                        "SSSSSsHu",
                        "SbbbbbbU"[:8],
                        "bbbbbbbb",
                        ".bbbbbb."],
        "torso_top":   ["AAAAAAAA",   # fourrure
                        "aAAAAAAa",
                        "UUUUUUUU",
                        "uuuuuuuu"],
        "torso_bottom":["uuuuuuuu",
                        "uPPPPPPu",
                        "uPPPPPPu",
                        "uuuuuuuu"],
        "torso_front": ["AaAAAAaA",   # cape fourrure
                        "AAAAAAAA",
                        "aUUUUUUa",
                        "UUUuuUUU",   # capuchon attaché
                        "UUUUUUUU",
                        "UUUUUUUU",
                        "UUUUUUUU",
                        "UUUUUUUU",
                        "UuuUUuuU",
                        "uuuuuuuu",   # ceinture
                        "UUUUUUUU",
                        "uUUUUUUu"],
        "torso_back":  ["AAAAAAAA"] + ["aAAAAAAa"] + ["UUUUUUUU"] * 4 +
                       ["UUUuuUUU", "uuuuuuuu"] + ["UUUUUUUU"] * 4,
        "torso_right": ["AAAA"] + torso_side("U", "u")[1:],
        "torso_left":  ["AAAA"] + torso_side("U", "u")[1:],
        "arm_r_top":   ["AAAA"]*2 + ["UUUU"]*2,
        "arm_r_bottom":["SSSS"]*4,
        "arm_r_right": ["AAAA"]*2 + ["UUUU"]*7 + ["uuuu"] + ["SSSS"]*2,
        "arm_r_front": ["AAAA"]*2 + ["UUUU"]*7 + ["uuuu", "SSSS", "SsSS"],
        "arm_r_left":  ["AAAA"]*2 + ["UUUU"]*7 + ["uuuu"] + ["SSSS"]*2,
        "arm_r_back":  ["AAAA"]*2 + arm_back("U", "u", "S")[2:],
        "leg_r_top":   ["uuuu","uPPu","uPPu","uuuu"],
        "leg_r_bottom":["BBBB"]*4,
        "leg_r_right": ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_front": ["PPPP"]*9 + ["uuuu", "BBBB", "BBBB"],
        "leg_r_left":  ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_back":  leg_back("P", "B"),
    },
}

# ---------------------------------------------------------------------------
# Heimdall : casque cornu, armure dorée Asgard
# ---------------------------------------------------------------------------
HEIMDALL = {
    "palette": {
        ".": None,
        "S": "#d8b890", "s": "#a88860", "l": "#e8c8a0",
        "H": "#f0e0a0", "h": "#fff0b8", "d": "#a88830",  # blond doré
        "b": "#a06028", "E": "#f0d040", "M": "#5a3a2a",  # yeux dorés
        "U": "#d8a820", "u": "#886a10",                  # armure or
        "A": "#fff0c0", "a": "#c89a18",                  # éclat
        "G": "#5a4030",                                  # cuir brun
        "X": "#f8e0a0",                                  # corne os
        "P": "#5a4030", "B": "#a87820",
    },
    "regions": {
        "head_top":    [".XX..XX.",   # cornes du casque
                        "XXXuuXXX",
                        "XXuuuuXX",
                        "uuuuuuuu",
                        "uuuuuuuu",
                        "uUUUUUUu",
                        "uUuuuuUu",
                        ".UUUUUU."],
        "head_bottom": [".SSSSSS.",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        ".SSSSSS."],
        "head_front":  ["uUUUUUUu",   # casque doré
                        "UAUUUUAU",
                        "UuSSSSuU",   # visière
                        "USEsSEsU",
                        "USSSlSSU",
                        "uSSbbSSu",   # bouc
                        "SSSbbSSS",
                        ".SSSSSS."],
        "head_back":   ["uUUUUUUu",
                        "UAUUUUAU",
                        "UUUUUUUU",
                        "UUUHHUUU",   # cheveux dépassant
                        "UHHHHHHU",
                        "UHHHHHHU",
                        "HHHHHHHH",
                        ".SSSSSS."],
        "head_right":  ["uUUUUUUu",
                        "UAUUUUAU",
                        "UUUUSSSS",
                        "UUUuSSSS",
                        "UUUUsSSS",
                        "uUSSSSSS",
                        "USSSSSSS",
                        ".SSSSSS."],
        "head_left":   ["uUUUUUUu",
                        "UAUUUUAU",
                        "SSSSUUUU",
                        "SSSSuUUU",
                        "SSSsUUUU",
                        "SSSSSSUu",
                        "SSSSSSSU",
                        ".SSSSSS."],
        "torso_top":   ["UUUUUUUU",
                        "UAAAAAAU",
                        "UuUUUUuU",
                        "uuuuuuuu"],
        "torso_bottom":["uuuuuuuu",
                        "uPPPPPPu",
                        "uPPPPPPu",
                        "uuuuuuuu"],
        "torso_front": ["UAAAAAAU",   # plastron or
                        "UAuuuuAU",
                        "UuUaaUuU",   # médaillon
                        "UUaAAaUU",
                        "UUaAAaUU",
                        "UuUaaUuU",
                        "UAuuuuAU",
                        "UUUUUUUU",
                        "UuUUUUuU",
                        "uuuuuuuu",
                        "GGGGGGGG",
                        "GgGGGGgG".replace("g", "G")],
        "torso_back":  torso_back("U", "u"),
        "torso_right": torso_side("U", "u"),
        "torso_left":  torso_side("U", "u"),
        "arm_r_top":   ["UUUU"]*4,
        "arm_r_bottom":["SSSS"]*4,
        "arm_r_right": ["UUUU"]*8 + ["AAAA", "uuuu"] + ["SSSS"]*2,
        "arm_r_front": ["UUUU"]*8 + ["AAAA", "uuuu", "SSSS", "SsSS"],
        "arm_r_left":  ["UUUU"]*8 + ["AAAA", "uuuu"] + ["SSSS"]*2,
        "arm_r_back":  arm_back("U", "u", "S"),
        "leg_r_top":   ["uuuu","uPPu","uPPu","uuuu"],
        "leg_r_bottom":["BBBB"]*4,
        "leg_r_right": ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_front": ["GGGG","GGGG","GGGG","PPPP","PPPP","PPPP","PPPP","PPPP","PPPP",
                        "uuuu", "BBBB","BBBB"],
        "leg_r_left":  ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_back":  leg_back("P", "B"),
    },
}

# ---------------------------------------------------------------------------
# Gandalf : chapeau pointu gris, longue barbe blanche, robe grise
# ---------------------------------------------------------------------------
GANDALF = {
    "palette": {
        ".": None,
        "S": "#e8c8a0", "s": "#b89878", "l": "#f0d8b8",
        "H": "#f8f8f8", "h": "#ffffff", "d": "#a8a8b0",
        "b": "#f8f8f8", "E": "#4a4a6a", "M": "#883a2a",
        "U": "#888890", "u": "#5a5a60",                  # robe grise
        "A": "#3a2a18", "a": "#1a0e08",                  # ceinture brune
        "G": "#5a5a60",                                  # chapeau gris foncé
        "P": "#5a5a60", "B": "#3a2a18",
    },
    "regions": {
        "head_top":    ["...GG...",   # pointe chapeau
                        "..GGGG..",
                        ".GGGGGG.",
                        "GGGGGGGG",
                        "GGGGGGGG",
                        "GGGGGGGG",
                        "GGGGGGGG",
                        "GGGGGGGG"],
        "head_bottom": [".bbbbbb.",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        "bbbbbbbb",
                        ".bbbbbb."],
        "head_front":  ["GGGGGGGG",   # bord chapeau
                        "GGGGGGGG",
                        "HSSSSSSH",   # cheveux blancs
                        "HSEssEsH",
                        "HSSSlSSH",
                        "HbbbbbbH",   # barbe touffue
                        "bbbbbbbb",
                        "bbbbbbbb"],
        "head_back":   ["GGGGGGGG",
                        "GGGGGGGG",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH",
                        "HHHHHHHH"],
        "head_right":  ["GGGGGGGG",
                        "GGGGGGGG",
                        "HHHHSSSS",
                        "HHHsSSSS",
                        "HHsSSSSS",
                        "HbbbbbbS",
                        "bbbbbbbb",
                        "bbbbbbbb"],
        "head_left":   ["GGGGGGGG",
                        "GGGGGGGG",
                        "SSSSHHHH",
                        "SSSSsHHH",
                        "SSSSSsHH",
                        "SbbbbbbH",
                        "bbbbbbbb",
                        "bbbbbbbb"],
        "torso_top":   ["bbbbbbbb",   # barbe descend
                        "bbUUUUbb",
                        "UUUUUUUU",
                        "uUUUUUUu"],
        "torso_bottom":["uuuuuuuu",
                        "uPPPPPPu",
                        "uPPPPPPu",
                        "uuuuuuuu"],
        "torso_front": ["bbbbbbbb",   # barbe sur poitrine
                        "ubbbbbbbu"[:8],
                        "UbbbbbbU",
                        "UUbbbbUU",
                        "UUUbbUUU",
                        "UUUUUUUU",
                        "UUUUUUUU",
                        "AAAAAAAA",   # ceinture
                        "aaaaaaaa",
                        "UUUUUUUU",
                        "UUUUUUUU",
                        "uUUUUUUu"],
        "torso_back":  torso_back("U", "A"),
        "torso_right": torso_side("U", "A"),
        "torso_left":  torso_side("U", "A"),
        "arm_r_top":   ["UUUU"]*4,
        "arm_r_bottom":["SSSS"]*4,
        "arm_r_right": ["UUUU"]*9 + ["uuuu"] + ["SSSS"]*2,
        "arm_r_front": ["UUUU"]*9 + ["uuuu", "SSSS", "SsSS"],
        "arm_r_left":  ["UUUU"]*9 + ["uuuu"] + ["SSSS"]*2,
        "arm_r_back":  arm_back("U", "u", "S"),
        "leg_r_top":   ["uuuu","uPPu","uPPu","uuuu"],
        "leg_r_bottom":["BBBB"]*4,
        "leg_r_right": ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_front": ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_left":  ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_back":  leg_back("P", "B"),
    },
}

# ---------------------------------------------------------------------------
# Janus : deux faces (avant ET arrière), couronne or, toge pourpre
# ---------------------------------------------------------------------------
JANUS = {
    "palette": {
        ".": None,
        "S": "#c8a880", "s": "#987850", "l": "#d8b890",
        "H": "#6a3a8a", "h": "#9a6abc", "d": "#3a1a5a",  # mystique violet
        "b": "#6a3a8a", "E": "#f0e0a0", "M": "#4a2a3a",
        "U": "#5a2a7a", "u": "#3a1858",                  # toge pourpre
        "A": "#f0d040", "a": "#a08020",                  # bordure or
        "G": "#f0d040",                                  # diadème or
        "P": "#3a1858", "B": "#1a0e20",
    },
    "regions": {
        "head_top":    ["GGGGGGGG",   # diadème vu de haut
                        "GHhhhhHG",
                        "GHhhhhHG",
                        "GhhhhhhG",
                        "GhhhhhhG",
                        "GHhhhhHG",
                        "GHhhhhHG",
                        "GGGGGGGG"],
        "head_bottom": [".SSSSSS.",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        "SSSSSSSS",
                        ".SSSSSS."],
        "head_front":  ["GGGGGGGG",   # face A
                        "HHHHHHHH",
                        "HSSSSSSH",
                        "HSEsSEsH",
                        "HSSSlSSH",
                        "HSSSSSSH",
                        "HSSMMSSH",
                        ".SSSSSS."],
        "head_back":   ["GGGGGGGG",   # face B (l'autre visage)
                        "HHHHHHHH",
                        "HSSSSSSH",
                        "HsEsSsEH",
                        "HSSlSSSH",
                        "HSSSSSSH",
                        "HSSMMSSH",
                        ".SSSSSS."],
        "head_right":  ["GGGGGGGG",
                        "HHHHHHHH",
                        "HSSSSSSH",   # profil neutre, deux côtés symétriques
                        "HsSSSSsH",
                        "HSSSSSSH",
                        "HSSSSSSH",
                        "HSSSSSSH",
                        ".SSSSSS."],
        "head_left":   ["GGGGGGGG",
                        "HHHHHHHH",
                        "HSSSSSSH",
                        "HsSSSSsH",
                        "HSSSSSSH",
                        "HSSSSSSH",
                        "HSSSSSSH",
                        ".SSSSSS."],
        "torso_top":   ["AAAAAAAA",   # toge bordée or
                        "UAAAAAAu",
                        "UUUUUUUU",
                        "uuuuuuuu"],
        "torso_bottom":["uuuuuuuu",
                        "uPPPPPPu",
                        "uPPPPPPu",
                        "uuuuuuuu"],
        "torso_front": ["AAAAAAAA",   # toge avant
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAaAAaAU",   # broche or
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAaaaaAU",
                        "UAUUUUAU",
                        "uAAAAAAu"],
        "torso_back":  ["AAAAAAAA",   # toge arrière (l'autre face)
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAaAAaAU",
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAUUUUAU",
                        "UAaaaaAU",
                        "UAUUUUAU",
                        "uAAAAAAu"],
        "torso_right": ["UAAU"] + torso_side("U", "A")[1:],
        "torso_left":  ["UAAU"] + torso_side("U", "A")[1:],
        "arm_r_top":   ["UUUU"]*4,
        "arm_r_bottom":["SSSS"]*4,
        "arm_r_right": ["UUUU"]*8 + ["AAAA"] + ["UUUU"] + ["SSSS"]*2,
        "arm_r_front": ["UUUU"]*8 + ["AAAA", "UUUU", "SSSS", "SsSS"],
        "arm_r_left":  ["UUUU"]*8 + ["AAAA"] + ["UUUU"] + ["SSSS"]*2,
        "arm_r_back":  ["UUUU"]*8 + ["AAAA"] + ["UUUU"] + ["SSSS"]*2,
        "leg_r_top":   ["uuuu","uPPu","uPPu","uuuu"],
        "leg_r_bottom":["BBBB"]*4,
        "leg_r_right": ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_front": ["PPPP"]*9 + ["uuuu", "BBBB", "BBBB"],
        "leg_r_left":  ["PPPP"]*10 + ["BBBB"]*2,
        "leg_r_back":  leg_back("P", "B"),
    },
}

# ---------------------------------------------------------------------------
GUARDIANS = {
    "tgw_guardian_trump":    TRUMP,
    "tgw_guardian_qin":      QIN,
    "tgw_guardian_hadrian":  HADRIAN,
    "tgw_guardian_vauban":   VAUBAN,
    "tgw_guardian_jon_snow": JON,
    "tgw_guardian_heimdall": HEIMDALL,
    "tgw_guardian_gandalf":  GANDALF,
    "tgw_guardian_janus":    JANUS,
}


def validate(name, regions, expected):
    """Garantit que chaque région a les bonnes dimensions."""
    for region, grid in regions.items():
        exp_w, exp_h = expected[region]
        assert len(grid) == exp_h, f"{name}.{region}: {len(grid)} lignes, attendu {exp_h}"
        for j, row in enumerate(grid):
            assert len(row) == exp_w, (
                f"{name}.{region}[{j}]: largeur {len(row)} '{row}', attendu {exp_w}")


REGION_DIMS = {
    "head_top": (8, 8), "head_bottom": (8, 8), "head_right": (8, 8),
    "head_front": (8, 8), "head_left": (8, 8), "head_back": (8, 8),
    "torso_top": (8, 4), "torso_bottom": (8, 4),
    "torso_right": (4, 12), "torso_front": (8, 12),
    "torso_left": (4, 12), "torso_back": (8, 12),
    "arm_r_top": (4, 4), "arm_r_bottom": (4, 4),
    "arm_r_right": (4, 12), "arm_r_front": (4, 12),
    "arm_r_left": (4, 12), "arm_r_back": (4, 12),
    "leg_r_top": (4, 4), "leg_r_bottom": (4, 4),
    "leg_r_right": (4, 12), "leg_r_front": (4, 12),
    "leg_r_left": (4, 12), "leg_r_back": (4, 12),
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in GUARDIANS.items():
        validate(name, spec["regions"], REGION_DIMS)
        atlas = {
            "name": name,
            "rig": "mc_humanoid_64x32",
            "palette": spec["palette"],
            "regions": spec["regions"],
        }
        proc = subprocess.run(
            CLI, input=json.dumps(atlas),
            text=True, capture_output=True,
            env={"PYTHONPATH": str(ROOT / "tools/sprite_gen"),
                 "PATH": "/usr/bin:/bin"},
        )
        if proc.returncode != 0:
            print(f"FAIL {name}: {proc.stderr}", file=sys.stderr)
            return proc.returncode
        print(proc.stdout.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
