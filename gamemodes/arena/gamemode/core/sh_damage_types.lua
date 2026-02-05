-- core/sh_damage_types.lua
-- Damage type enums and modifier tables

ARENA.DamageTypes = {
    GENERIC    = 0,
    BALLISTIC  = 1,   -- Hitscan weapons
    EXPLOSIVE  = 2,   -- Splash damage
    FIRE       = 3,
    ICE        = 4,
    ELECTRIC   = 5,
    MELEE      = 6,
    TRUE       = 7,   -- Bypasses armor/shield
}

-- Reverse lookup for debug printing
ARENA.DamageTypeNames = {}
for name, id in pairs(ARENA.DamageTypes) do
    ARENA.DamageTypeNames[id] = name
end
