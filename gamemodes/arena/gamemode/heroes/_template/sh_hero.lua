-- heroes/YOUR_HERO_NAME/sh_hero.lua
-- Copy this folder to heroes/your_hero/ and fill in the details.

local HERO = {}

-- Identity
HERO.Name        = "Hero Name"
HERO.Description = "One-line description of what this hero does."
HERO.Role        = "DPS"      -- Tank / DPS / Support
HERO.Icon        = "arena/heroes/your_hero/icon.png"

-- Base Stats
HERO.Health    = 200
HERO.Shield    = 0
HERO.Armor     = 0
HERO.MoveSpeed = 250

-- Ability Bindings (slot → ability ID)
-- Every ability ID must be globally unique. Convention: heroname_abilityname
HERO.Abilities = {
    [ARENA_SLOT_PRIMARY]   = "yourhero_primary",
    [ARENA_SLOT_SECONDARY] = "yourhero_secondary",
    [ARENA_SLOT_ABILITY1]  = "yourhero_ability1",
    [ARENA_SLOT_ABILITY2]  = "yourhero_ability2",
    [ARENA_SLOT_ULTIMATE]  = "yourhero_ultimate",
}

-- Passive (optional)
-- Available callbacks: OnTakeDamage(ply, dmgInfo), OnDealDamage(ply, dmgInfo)
HERO.Passive = {
    Name = "Passive Name",
    Description = "What the passive does.",
    -- OnTakeDamage = function(ply, dmgInfo) end,
    -- OnDealDamage = function(ply, dmgInfo) end,
}

-- Movement modifiers (optional)
HERO.Movement = {
    CanDoubleJump = false,
    CanWallRun    = false,
    CanHover      = false,
    CustomMove    = nil,  -- function(ply, mv) for fully custom movement
}

-- IMPORTANT: Change "your_hero" to your hero's ID (lowercase, no spaces)
-- ARENA:RegisterHero("your_hero", HERO)
