-- config/sh_game_config.lua
-- Global game configuration and balance knobs

ARENA.Config = {
    -- Team
    TeamSize = 6,
    TeamCount = 2,
    AllowSpectators = true,

    -- Match
    GameMode = "round_based",  -- "round_based", "koth", "payload", "deathmatch"
    RoundsToWin = 3,
    RoundTime = 180,
    HeroSelectTime = 30,
    PreRoundTime = 5,
    RoundEndTime = 8,
    AllowHeroSwap = true,
    AllowMirror = true,

    -- Respawn
    RespawnTime = 5,
    RespawnWave = false,

    -- Balance
    GlobalDamageScale = 1.0,
    GlobalHealingScale = 1.0,
    HeadshotMultiplier = 2.0,
    UltChargeRate = 1.0,

    -- Shield
    ShieldRegenDelay = 3.0,    -- Seconds after last damage before shield regens
    ShieldRegenRate = 20,      -- Shield points per second during regen

    -- Dev
    DevMode = true,
    DebugDamage = true,
}

-- Ultimate charge tuning
ARENA.UltChargeConfig = {
    MaxCharge      = 100,
    DamageRatio    = 0.01,    -- 1 charge per 100 damage dealt
    HealingRatio   = 0.015,   -- 1.5 charge per 100 healing done
    PassiveRate    = 1.0,     -- Charge per second (passive gain)
    DeathPenalty   = 0,       -- Charge lost on death (0 = keep all)
    ObjectiveBonus = 5,       -- Bonus for objective ticks
}
