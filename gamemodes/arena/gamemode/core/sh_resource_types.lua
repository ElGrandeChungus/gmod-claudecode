-- core/sh_resource_types.lua
-- All enums for the Arena gamemode. Loaded first before anything else.

------------------------------------------------------------
-- Resource Types (per-ability resource model)
------------------------------------------------------------
ARENA_RESOURCE_NONE     = 0   -- Always available (passives)
ARENA_RESOURCE_COOLDOWN = 1   -- Simple cooldown timer
ARENA_RESOURCE_AMMO     = 2   -- Finite ammo with reload
ARENA_RESOURCE_ENERGY   = 3   -- Regenerating energy pool
ARENA_RESOURCE_CHARGES  = 4   -- Discrete charges that regen independently

------------------------------------------------------------
-- Activation Types
------------------------------------------------------------
ARENA_ACTIVATION_INSTANT  = 0   -- Fires once on press
ARENA_ACTIVATION_HOLD     = 1   -- Active while button held, calls OnTick
ARENA_ACTIVATION_TOGGLE   = 2   -- Press to activate, press again to deactivate
ARENA_ACTIVATION_CHANNEL  = 3   -- Locks player in place for duration, calls OnTick
ARENA_ACTIVATION_CHARGE   = 4   -- Hold to charge, fires on release via OnRelease

------------------------------------------------------------
-- Ability Slots
------------------------------------------------------------
ARENA_SLOT_PRIMARY    = 1   -- Mouse1
ARENA_SLOT_SECONDARY  = 2   -- Mouse2
ARENA_SLOT_ABILITY1   = 3   -- Shift
ARENA_SLOT_ABILITY2   = 4   -- E
ARENA_SLOT_ULTIMATE   = 5   -- Q
ARENA_SLOT_PASSIVE    = 6   -- No binding, always active
ARENA_SLOT_MELEE      = 7   -- V (quick melee, optional)

------------------------------------------------------------
-- Slot → Input Mappings (client-side IN_ enums)
------------------------------------------------------------
ARENA.SlotBinds = {
    [ARENA_SLOT_PRIMARY]   = IN_ATTACK,
    [ARENA_SLOT_SECONDARY] = IN_ATTACK2,
    [ARENA_SLOT_ABILITY1]  = IN_SPEED,      -- Shift
    [ARENA_SLOT_ABILITY2]  = IN_USE,        -- E
    [ARENA_SLOT_ULTIMATE]  = IN_GRENADE1,   -- Bound to Q via console
    [ARENA_SLOT_MELEE]     = IN_GRENADE2,   -- Bound to V via console
}

------------------------------------------------------------
-- Match States
------------------------------------------------------------
ARENA_STATE_WARMUP      = 0
ARENA_STATE_HERO_SELECT = 1
ARENA_STATE_PRE_ROUND   = 2
ARENA_STATE_ACTIVE      = 3
ARENA_STATE_ROUND_END   = 4
ARENA_STATE_MATCH_END   = 5

------------------------------------------------------------
-- Team Indices
------------------------------------------------------------
ARENA_TEAM_SPECTATOR = TEAM_SPECTATOR or 1002
ARENA_TEAM_1         = 1
ARENA_TEAM_2         = 2
