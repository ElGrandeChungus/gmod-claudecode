-- heroes/breaker/sh_hero.lua
-- Breaker: Front-line tank brawler

local HERO = {}

-- Identity
HERO.Name        = "Breaker"
HERO.Description = "Front-line brawler who controls space with brute force."
HERO.Role        = "Tank"
HERO.Icon        = "arena/heroes/breaker/icon.png"

-- Base Stats
HERO.Health    = 250
HERO.Shield    = 50
HERO.Armor     = 25
HERO.MoveSpeed = 220

-- Ability Bindings (slot → ability ID)
HERO.Abilities = {
    [ARENA_SLOT_PRIMARY]   = "breaker_shotgun",
    [ARENA_SLOT_SECONDARY] = "breaker_shield_bash",
    [ARENA_SLOT_ABILITY1]  = "breaker_charge",
    [ARENA_SLOT_ABILITY2]  = "breaker_fortify",
    [ARENA_SLOT_ULTIMATE]  = "breaker_shockwave",
}

-- Passive: Juggernaut — 15% knockback reduction from all sources
HERO.Passive = {
    Name = "Juggernaut",
    Description = "Take 15% less knockback from all sources.",
    OnTakeDamage = function(ply, dmgInfo)
        -- Reduce knockback force by 15%
        dmgInfo.Knockback = dmgInfo.Knockback * 0.85
    end,
}

-- Movement modifiers
HERO.Movement = {
    CanDoubleJump = false,
    CanWallRun    = false,
    CanHover      = false,
    CustomMove    = nil,
}

ARENA:RegisterHero("breaker", HERO)
