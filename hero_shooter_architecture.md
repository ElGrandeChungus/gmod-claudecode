# Hero Shooter Gamemode — Architecture Document
## GMod Custom Gamemode: "Arena" (Working Title)

---

## 1. Project Overview

A modular, data-driven hero shooter gamemode for Garry's Mod designed for rapid prototyping of hero kits. The architecture prioritizes:

- **Composability** — Heroes are assembled from reusable atomic ability components
- **Flexibility** — Per-ability resource systems (cooldown, ammo, energy, charges, hybrid)
- **Scalability** — Default 6v6, configurable for 5v5, 12v12, FFA, etc.
- **Rapid iteration** — New heroes defined in single files, hot-reloadable during development

---

## 2. Directory Structure

```
gamemodes/
└── arena/
    ├── arena.txt                    -- Gamemode metadata
    ├── gamemode/
    │   ├── init.lua                 -- Server entry point
    │   ├── cl_init.lua              -- Client entry point
    │   ├── shared.lua               -- Shared globals, enums, config
    │   │
    │   ├── core/                    -- Core framework systems
    │   │   ├── sh_hero_registry.lua     -- Hero registration & lookup
    │   │   ├── sh_ability_base.lua      -- Base ability class
    │   │   ├── sh_resource_types.lua    -- Resource system definitions
    │   │   ├── sh_status_effects.lua    -- Status effect registry & logic
    │   │   ├── sh_damage_types.lua      -- Damage type enums & modifiers
    │   │   ├── sv_hero_manager.lua      -- Server: hero assignment, spawning
    │   │   ├── sv_ability_executor.lua  -- Server: ability activation & validation
    │   │   ├── sv_combat.lua            -- Server: damage pipeline, kill tracking
    │   │   ├── sv_round_manager.lua     -- Server: round/match state machine
    │   │   ├── sv_team_manager.lua      -- Server: team balancing, assignment
    │   │   ├── cl_hud.lua               -- Client: HUD rendering
    │   │   ├── cl_hero_select.lua       -- Client: hero selection screen
    │   │   └── cl_killfeed.lua          -- Client: kill feed display
    │   │
    │   ├── heroes/                  -- Hero definitions (one folder per hero)
    │   │   ├── breaker/
    │   │   │   ├── sh_hero.lua          -- Hero stats & ability bindings
    │   │   │   ├── abilities/
    │   │   │   │   ├── sh_shotgun.lua
    │   │   │   │   ├── sh_shield_bash.lua
    │   │   │   │   ├── sh_charge.lua
    │   │   │   │   ├── sh_fortify.lua
    │   │   │   │   └── sh_shockwave.lua
    │   │   │   └── cl_hud_custom.lua    -- Optional hero-specific HUD elements
    │   │   └── _template/               -- Copy this to create new heroes
    │   │       ├── sh_hero.lua
    │   │       └── abilities/
    │   │           └── sh_template_ability.lua
    │   │
    │   ├── effects/                 -- Shared visual/physical effect definitions
    │   │   ├── sh_effect_registry.lua
    │   │   ├── cl_particle_effects.lua
    │   │   └── sv_physics_effects.lua
    │   │
    │   ├── interaction/             -- Effect interaction system (CRES-style)
    │   │   ├── sh_interaction_matrix.lua
    │   │   └── sh_interaction_rules.lua
    │   │
    │   └── config/
    │       ├── sh_game_config.lua       -- Match settings, team sizes, timers
    │       └── sh_balance_config.lua    -- Global balance knobs
    │
    └── content/                     -- Models, materials, sounds (or Workshop refs)
        ├── materials/
        ├── models/
        └── sound/
```

**Naming convention:** `sh_` = shared (runs on both client and server), `sv_` = server only, `cl_` = client only. This is critical in GMod — running server logic on the client is a security risk and running client render code on the server will crash.

---

## 3. Core Systems

### 3.1 Hero Registry (`sh_hero_registry.lua`)

Central lookup table for all heroes. Heroes self-register on load.

```lua
ARENA.Heroes = ARENA.Heroes or {}

function ARENA:RegisterHero(id, heroTable)
    heroTable.ID = id
    heroTable.Abilities = heroTable.Abilities or {}
    self.Heroes[id] = heroTable
    print("[Arena] Registered hero: " .. heroTable.Name .. " (" .. id .. ")")
end

function ARENA:GetHero(id)
    return self.Heroes[id]
end

function ARENA:GetAllHeroes()
    return self.Heroes
end

-- Called by each hero's sh_hero.lua
-- Example: ARENA:RegisterHero("breaker", HERO)
```

### 3.2 Hero Definition Schema

Each hero's `sh_hero.lua` defines a table conforming to this schema:

```lua
local HERO = {}

-- Identity
HERO.Name        = "Breaker"
HERO.Description = "Front-line brawler who controls space with brute force."
HERO.Role        = "Tank"         -- Tank / DPS / Support (for UI grouping)
HERO.Icon        = "arena/heroes/breaker/icon.png"

-- Base Stats
HERO.Health      = 250
HERO.Shield      = 50             -- Regenerating shield (recharges after delay)
HERO.Armor       = 25             -- Flat damage reduction
HERO.MoveSpeed   = 220            -- Units/sec (GMod default walk ~200, run ~400)

-- Ability Bindings (slot -> ability ID)
-- Ability IDs resolve to files in this hero's abilities/ folder
HERO.Abilities = {
    [ARENA_SLOT_PRIMARY]   = "breaker_shotgun",       -- Mouse1
    [ARENA_SLOT_SECONDARY] = "breaker_shield_bash",   -- Mouse2
    [ARENA_SLOT_ABILITY1]  = "breaker_charge",        -- Shift
    [ARENA_SLOT_ABILITY2]  = "breaker_fortify",       -- E
    [ARENA_SLOT_ULTIMATE]  = "breaker_shockwave",     -- Q
}

-- Passive (optional) — a function that hooks into game events
HERO.Passive = {
    Name = "Juggernaut",
    Description = "Take 15% less knockback from all sources.",
    OnTakeDamage = function(ply, dmginfo)
        -- Reduce knockback force
        local force = dmginfo:GetDamageForce()
        dmginfo:SetDamageForce(force * 0.85)
    end,
}

-- Movement modifiers (optional)
HERO.Movement = {
    CanDoubleJump  = false,
    CanWallRun     = false,
    CanHover       = false,
    CustomMove     = nil,  -- function(ply, mv, cmd) for fully custom movement
}

ARENA:RegisterHero("breaker", HERO)
```

### 3.3 Ability Base Class (`sh_ability_base.lua`)

All abilities inherit from this base. Each ability is a table with a standardized interface:

```lua
ARENA.AbilityBase = {}

function ARENA.AbilityBase:New(id)
    local ability = setmetatable({}, { __index = self })

    ability.ID          = id
    ability.Name        = "Unnamed Ability"
    ability.Description = ""
    ability.Slot        = ARENA_SLOT_ABILITY1

    -- Resource configuration (per-ability hybrid system)
    ability.Resource = {
        Type     = ARENA_RESOURCE_COOLDOWN, -- COOLDOWN, AMMO, ENERGY, CHARGES, NONE
        Cooldown = 0,          -- Seconds (used by all types as minimum reuse time)
        MaxAmmo  = 0,          -- For AMMO type
        AmmoPerUse = 1,        -- Ammo consumed per activation
        ReloadTime = 0,        -- Seconds to reload full ammo
        MaxEnergy = 0,         -- For ENERGY type
        EnergyCost = 0,        -- Energy consumed per activation
        EnergyRegen = 0,       -- Energy regenerated per second
        MaxCharges = 0,        -- For CHARGES type
        ChargeRegenTime = 0,   -- Seconds per charge regeneration
    }

    -- State tracking (managed by framework, don't set manually)
    ability._cooldownEnd = 0
    ability._currentAmmo = 0
    ability._currentEnergy = 0
    ability._currentCharges = 0
    ability._isActive = false
    ability._channelStart = 0

    -- Activation type
    ability.ActivationType = ARENA_ACTIVATION_INSTANT
    -- INSTANT: fires once on press
    -- HOLD: active while button held, calls OnTick
    -- TOGGLE: press to activate, press again to deactivate
    -- CHANNEL: locks player in place for duration, calls OnTick
    -- CHARGE: hold to charge, fires on release via OnRelease

    ability.Duration = 0       -- For HOLD/TOGGLE/CHANNEL: max active time (0 = unlimited)
    ability.ChargeTime = 0     -- For CHARGE: time to reach full charge

    return ability
end

-- Override these in ability definitions --

-- Called when ability activates (server)
function ARENA.AbilityBase:OnActivate(ply) end

-- Called every tick while active (server, for HOLD/TOGGLE/CHANNEL)
function ARENA.AbilityBase:OnTick(ply, dt) end

-- Called when ability deactivates (server)
function ARENA.AbilityBase:OnDeactivate(ply) end

-- Called on button release (server, for CHARGE type)
function ARENA.AbilityBase:OnRelease(ply, chargePercent) end

-- Called when ability goes on cooldown (shared, for UI feedback)
function ARENA.AbilityBase:OnCooldownStart(ply) end

-- Can this ability be activated right now? (shared, for UI dimming)
function ARENA.AbilityBase:CanActivate(ply)
    return self:HasResource(ply) and not self:IsOnCooldown()
end

-- Client-side: custom crosshair, indicators, etc.
function ARENA.AbilityBase:DrawHUD(ply) end

-- Client-side: preview/targeting indicator (e.g., grenade arc)
function ARENA.AbilityBase:DrawTargeting(ply) end
```

### 3.4 Resource System (`sh_resource_types.lua`)

Enums and helper functions for the hybrid resource model:

```lua
-- Resource type enums
ARENA_RESOURCE_NONE     = 0   -- Always available (passives)
ARENA_RESOURCE_COOLDOWN = 1   -- Simple cooldown timer
ARENA_RESOURCE_AMMO     = 2   -- Finite ammo with reload
ARENA_RESOURCE_ENERGY   = 3   -- Regenerating energy pool
ARENA_RESOURCE_CHARGES  = 4   -- Discrete charges that regen independently

-- Activation type enums
ARENA_ACTIVATION_INSTANT  = 0
ARENA_ACTIVATION_HOLD     = 1
ARENA_ACTIVATION_TOGGLE   = 2
ARENA_ACTIVATION_CHANNEL  = 3
ARENA_ACTIVATION_CHARGE   = 4

-- Ability slot enums
ARENA_SLOT_PRIMARY    = 1   -- Mouse1
ARENA_SLOT_SECONDARY  = 2   -- Mouse2
ARENA_SLOT_ABILITY1   = 3   -- Shift
ARENA_SLOT_ABILITY2   = 4   -- E
ARENA_SLOT_ULTIMATE   = 5   -- Q
ARENA_SLOT_PASSIVE    = 6   -- No binding, always active
ARENA_SLOT_MELEE      = 7   -- V (quick melee, optional)

-- Key bindings per slot (client)
ARENA.SlotBinds = {
    [ARENA_SLOT_PRIMARY]   = IN_ATTACK,
    [ARENA_SLOT_SECONDARY] = IN_ATTACK2,
    [ARENA_SLOT_ABILITY1]  = IN_SPEED,    -- Shift
    [ARENA_SLOT_ABILITY2]  = IN_USE,      -- E
    [ARENA_SLOT_ULTIMATE]  = IN_GRENADE1, -- Bound to Q via console
    [ARENA_SLOT_MELEE]     = IN_GRENADE2, -- Bound to V via console
}
```

### 3.5 Damage & Combat Pipeline (`sv_combat.lua`)

All damage flows through a centralized pipeline for consistency and interaction support:

```
[Ability fires] 
    → Create ARENA_DamageInfo
    → Pre-damage hooks (attacker passives, ability modifiers)
    → Interaction check (does this collide with active effects?)
    → Damage type modifiers (armor, shield, resistance)
    → Apply damage
    → Post-damage hooks (kill tracking, ult charge, status effects)
    → Kill event (if applicable)
```

```lua
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

-- Custom damage info structure
function ARENA:CreateDamageInfo()
    return {
        Attacker     = NULL,
        Victim       = NULL,
        Damage       = 0,
        DamageType   = ARENA.DamageTypes.GENERIC,
        AbilityID    = "",          -- Which ability dealt this
        HeroID       = "",          -- Which hero the attacker is playing
        IsHeadshot   = false,
        IsCritical   = false,
        Knockback    = Vector(0,0,0),
        StatusEffects = {},          -- Status effects to apply on hit
        Position     = Vector(0,0,0), -- Impact position
    }
end

-- Central damage processing (server)
function ARENA:ProcessDamage(dmgInfo)
    local victim = dmgInfo.Victim
    local attacker = dmgInfo.Attacker

    if not IsValid(victim) or not victim:Alive() then return end

    -- 1. Pre-damage hooks
    hook.Run("Arena_PreDamage", dmgInfo)

    -- Attacker passive modifiers
    local atkHero = self:GetPlayerHero(attacker)
    if atkHero and atkHero.Passive and atkHero.Passive.OnDealDamage then
        atkHero.Passive.OnDealDamage(attacker, dmgInfo)
    end

    -- 2. Check interaction matrix
    self:CheckInteractions(dmgInfo)

    -- 3. Apply resistances
    local finalDamage = dmgInfo.Damage

    -- Shield absorbs first
    local shield = victim:GetNW2Float("Arena_Shield", 0)
    if shield > 0 and dmgInfo.DamageType ~= ARENA.DamageTypes.TRUE then
        local absorbed = math.min(shield, finalDamage)
        victim:SetNW2Float("Arena_Shield", shield - absorbed)
        finalDamage = finalDamage - absorbed
    end

    -- Armor reduces remaining
    local armor = victim:GetNW2Float("Arena_Armor", 0)
    if armor > 0 and dmgInfo.DamageType ~= ARENA.DamageTypes.TRUE then
        finalDamage = finalDamage * (1 - (armor / (armor + 100))) -- Diminishing returns
    end

    -- Victim passive modifiers
    local vicHero = self:GetPlayerHero(victim)
    if vicHero and vicHero.Passive and vicHero.Passive.OnTakeDamage then
        vicHero.Passive.OnTakeDamage(victim, dmgInfo)
    end

    -- 4. Apply damage
    victim:SetHealth(math.max(0, victim:Health() - finalDamage))

    -- 5. Apply knockback
    if dmgInfo.Knockback:Length() > 0 then
        victim:SetVelocity(dmgInfo.Knockback)
    end

    -- 6. Apply status effects
    for _, effect in ipairs(dmgInfo.StatusEffects) do
        self:ApplyStatusEffect(victim, effect.id, effect.duration, attacker)
    end

    -- 7. Ult charge generation
    if IsValid(attacker) and attacker:IsPlayer() then
        self:AddUltCharge(attacker, finalDamage * 0.01) -- 1% ult per damage point
    end

    -- 8. Post-damage hooks
    hook.Run("Arena_PostDamage", dmgInfo, finalDamage)

    -- 9. Kill check
    if victim:Health() <= 0 then
        self:OnPlayerKilled(victim, attacker, dmgInfo)
    end
end
```

### 3.6 Status Effect System (`sh_status_effects.lua`)

Data-driven status effects that can be applied by any ability:

```lua
ARENA.StatusEffects = {}

function ARENA:RegisterStatusEffect(id, effectTable)
    effectTable.ID = id
    self.StatusEffects[id] = effectTable
end

-- Example registrations
ARENA:RegisterStatusEffect("burning", {
    Name = "Burning",
    Duration = 4,
    TickRate = 0.5,       -- Damage every 0.5s
    StackBehavior = "refresh",  -- "refresh", "stack", "ignore"
    MaxStacks = 1,
    OnApply = function(ply, stacks, applier)
        -- Visual feedback
        if CLIENT then
            -- screen overlay, particle effect
        end
    end,
    OnTick = function(ply, stacks, applier)
        if SERVER then
            local dmg = ARENA:CreateDamageInfo()
            dmg.Attacker = applier
            dmg.Victim = ply
            dmg.Damage = 8 * stacks
            dmg.DamageType = ARENA.DamageTypes.FIRE
            ARENA:ProcessDamage(dmg)
        end
    end,
    OnRemove = function(ply)
        -- Clean up effects
    end,
})

ARENA:RegisterStatusEffect("slowed", {
    Name = "Slowed",
    Duration = 2,
    StackBehavior = "refresh",
    MaxStacks = 1,
    OnApply = function(ply, stacks, applier)
        if SERVER then
            ply:SetNW2Float("Arena_SpeedMult",
                ply:GetNW2Float("Arena_SpeedMult", 1.0) * 0.6)
        end
    end,
    OnRemove = function(ply)
        if SERVER then
            ply:SetNW2Float("Arena_SpeedMult", 1.0)
            -- Note: in production, recalculate from all active effects
        end
    end,
})

ARENA:RegisterStatusEffect("stunned", {
    Name = "Stunned",
    Duration = 1.5,
    StackBehavior = "refresh",
    MaxStacks = 1,
    OnApply = function(ply, stacks, applier)
        if SERVER then
            ply:Freeze(true)
            ply:SetNW2Bool("Arena_Stunned", true)
        end
    end,
    OnRemove = function(ply)
        if SERVER then
            ply:Freeze(false)
            ply:SetNW2Bool("Arena_Stunned", false)
        end
    end,
})
```

### 3.7 Interaction Matrix (`sh_interaction_matrix.lua`)

Inspired by the CRES system — defines what happens when effects/abilities collide:

```lua
ARENA.Interactions = {}

-- Register an interaction rule
-- When effectA hits/overlaps effectB, call the resolver
function ARENA:RegisterInteraction(effectA, effectB, resolver)
    local key = effectA .. ":" .. effectB
    self.Interactions[key] = resolver
end

function ARENA:CheckInteraction(effectA, effectB, context)
    local key = effectA .. ":" .. effectB
    local resolver = self.Interactions[key]
    if resolver then
        return resolver(context)
    end
    -- Check reverse
    local reverseKey = effectB .. ":" .. effectA
    resolver = self.Interactions[reverseKey]
    if resolver then
        return resolver(context)
    end
    return nil -- No interaction
end

-- Example rules
ARENA:RegisterInteraction("fire", "ice", function(ctx)
    -- Fire + Ice = both neutralize, create steam cloud (obscures vision)
    return {
        cancelA = true,
        cancelB = true,
        spawn = "steam_cloud",
        duration = 3,
        position = ctx.position,
    }
end)

ARENA:RegisterInteraction("electric", "water", function(ctx)
    -- Electric + Water zone = chain lightning to all players in water
    return {
        cancelA = false,
        cancelB = false,
        areaEffect = {
            type = "chain_damage",
            damageType = ARENA.DamageTypes.ELECTRIC,
            damage = 40,
            radius = ctx.waterRadius,
            targets = "in_water",
        },
    }
end)

ARENA:RegisterInteraction("knockback", "fortify", function(ctx)
    -- Knockback vs Fortified target = knockback negated
    return {
        cancelA = true,
        cancelB = false,
    }
end)
```

### 3.8 Ultimate System

Ult charge is tracked per-player and builds from dealing damage, healing, and objective participation:

```lua
-- In sv_combat.lua or a dedicated sv_ultimate.lua
ARENA.UltChargeConfig = {
    MaxCharge        = 100,
    DamageRatio      = 0.01,   -- 1 charge per 100 damage dealt
    HealingRatio     = 0.015,  -- 1.5 charge per 100 healing done
    PassiveRate      = 1.0,    -- Charge per second (passive gain)
    DeathPenalty     = 0,      -- Charge lost on death (0 = keep all)
    ObjectiveBonus   = 5,      -- Bonus for objective ticks
}

function ARENA:AddUltCharge(ply, amount)
    local current = ply:GetNW2Float("Arena_UltCharge", 0)
    local new = math.Clamp(current + amount, 0, self.UltChargeConfig.MaxCharge)
    ply:SetNW2Float("Arena_UltCharge", new)

    if new >= self.UltChargeConfig.MaxCharge then
        ply:SetNW2Bool("Arena_UltReady", true)
        -- Notify client for "ult ready" UI flash
        net.Start("Arena_UltReady")
        net.Send(ply)
    end
end
```

### 3.9 Round/Match Manager (`sv_round_manager.lua`)

State machine for match flow:

```
WARMUP → HERO_SELECT → PRE_ROUND → ROUND_ACTIVE → ROUND_END → (loop or MATCH_END)
```

```lua
ARENA.MatchStates = {
    WARMUP      = 0,  -- Players joining, free-for-all warmup
    HERO_SELECT = 1,  -- Hero selection phase
    PRE_ROUND   = 2,  -- Countdown, freeze time
    ACTIVE      = 3,  -- Round in progress
    ROUND_END   = 4,  -- Kill cam, stats
    MATCH_END   = 5,  -- Final scoreboard, map vote
}

ARENA.MatchConfig = {
    RoundsToWin   = 3,       -- Best of 5
    RoundTimeLimit = 180,    -- Seconds
    HeroSelectTime = 30,
    PreRoundTime   = 5,
    RoundEndTime   = 8,
    AllowHeroSwap  = true,   -- Can swap heroes between rounds
    AllowMirror    = true,   -- Both teams can pick same hero
    TeamSize       = 6,      -- Configurable: 5, 6, 12, etc.
}
```

---

## 4. Networking Strategy

### 4.1 Principles

- **Authoritative server**: All ability activation, damage, and state changes validated server-side
- **Client prediction**: Movement and instant-fire weapons predicted client-side for responsiveness
- **NW2 variables**: Used for per-player state that the HUD needs (health, shield, ult charge, active status effects)
- **Net messages**: Used for events (ability fired, kill event, round state changes)

### 4.2 Net Message Catalog

```lua
-- Server → Client
"Arena_AbilityActivated"     -- { ply, abilityID, position }
"Arena_AbilityDeactivated"   -- { ply, abilityID }
"Arena_StatusEffectApplied"  -- { ply, effectID, duration, stacks }
"Arena_StatusEffectRemoved"  -- { ply, effectID }
"Arena_PlayerKilled"         -- { victim, attacker, abilityID, headshot }
"Arena_RoundStateChanged"    -- { newState, data }
"Arena_UltReady"             -- (no data, sent to specific player)
"Arena_HeroChanged"          -- { ply, heroID }

-- Client → Server
"Arena_RequestAbility"       -- { slot } (client wants to activate ability)
"Arena_ReleaseAbility"       -- { slot } (client released button — for CHARGE type)
"Arena_SelectHero"           -- { heroID }
```

### 4.3 NW2 Variable Registry

```lua
-- Per-player networked variables (available to all clients for HUD rendering)
"Arena_HeroID"        -- string: current hero ID
"Arena_Health"        -- float: (we override default HP display)
"Arena_MaxHealth"     -- float
"Arena_Shield"        -- float: current shield
"Arena_MaxShield"     -- float
"Arena_Armor"         -- float
"Arena_UltCharge"     -- float: 0-100
"Arena_UltReady"      -- bool
"Arena_SpeedMult"     -- float: movement speed multiplier
"Arena_Stunned"       -- bool
"Arena_Team"          -- int: team index
```

---

## 5. HUD Design

### 5.1 Layout

```
┌─────────────────────────────────────────────────────┐
│  [Kill Feed - top right]                            │
│                                                     │
│                                                     │
│                                                     │
│               [Crosshair + Hit Marker]              │
│               [Ability Targeting Preview]            │
│                                                     │
│                                                     │
│  [Teammate Status - left]   [Score/Round - top]     │
│                                                     │
│         ┌─────────────────────────────┐             │
│         │  [HP Bar]  [Shield Bar]     │             │
│         │  [Ability1] [Ability2]      │             │
│         │  [Primary]  [Secondary]     │             │
│         │  [Ultimate - charge %]      │             │
│         └─────────────────────────────┘             │
└─────────────────────────────────────────────────────┘
```

### 5.2 Ability Icons Display

Each ability slot shows:
- Icon (from ability definition)
- Cooldown sweep (radial darkening animation)
- Charges remaining (for CHARGES type — pips)
- Ammo count (for AMMO type — number)
- Energy cost indicator (for ENERGY type — grayed if insufficient)
- Key binding label

---

## 6. Hero Template & Workflow

### 6.1 Creating a New Hero

1. Copy `heroes/_template/` to `heroes/your_hero_name/`
2. Edit `sh_hero.lua` with stats and ability bindings
3. Create ability files in `abilities/`
4. Restart server (or use dev hot-reload command)

### 6.2 Template Ability File

```lua
-- heroes/your_hero/abilities/sh_your_ability.lua
local ABILITY = ARENA.AbilityBase:New("your_hero_ability_name")

ABILITY.Name        = "Ability Name"
ABILITY.Description = "What this ability does."
ABILITY.Slot        = ARENA_SLOT_ABILITY1

ABILITY.Resource = {
    Type     = ARENA_RESOURCE_COOLDOWN,
    Cooldown = 8,
}

ABILITY.ActivationType = ARENA_ACTIVATION_INSTANT

function ABILITY:OnActivate(ply)
    -- Your ability logic here
    -- Use ARENA:CreateDamageInfo() for damage
    -- Use ARENA:ApplyStatusEffect() for effects
    -- Use ply:SetVelocity() for movement abilities
    -- Use ARENA:SpawnProjectile() for projectiles
end

ARENA:RegisterAbility(ABILITY)
```

---

## 7. Milestone 1: "Breaker" — Proof of Concept Hero

### Hero: Breaker (Tank)

| Stat | Value |
|------|-------|
| Health | 250 |
| Shield | 50 |
| Armor | 25 |
| Speed | 220 |

### Abilities

| Slot | Name | Type | Resource | Description |
|------|------|------|----------|-------------|
| Primary | Scrap Cannon | Hitscan (spread) | Ammo (6 shells, 1.5s reload) | Short-range shotgun, 8 pellets, 9 dmg each |
| Secondary | Shield Bash | Melee | Cooldown (5s) | Short-range cone attack, 50 dmg + brief stun (0.5s) |
| Shift | Bull Rush | Movement | Cooldown (10s) | Charge forward 15m, pin first enemy hit, 75 dmg on impact |
| E | Fortify | Self-buff (toggle) | Cooldown (8s), Duration 4s | Reduce incoming damage 40%, immune to knockback, but 50% move speed |
| Q (Ultimate) | Shockwave | Area damage | Ult charge (100) | Ground slam: 150 dmg in 8m radius, heavy knockback, 1s stun |

### Passive: Juggernaut
- 15% knockback reduction from all sources at all times

---

## 8. Physics Verb Library

A catalog of atomic physics operations that abilities compose from. This is the "kitchen sink" — new abilities are built by combining these:

| Verb | Function | Example Use |
|------|----------|-------------|
| `ApplyForce` | Push entity in direction | Knockback, charge, boops |
| `SpawnProjectile` | Create moving entity | Rockets, grenades, orbs |
| `Hitscan` | Instant trace-based damage | Bullets, beams |
| `CreateZone` | Persistent area effect | Healing field, fire puddle |
| `ModifyHealth` | Heal or damage | Healing abilities, lifesteal |
| `ApplyStatus` | Add status effect | Burn, slow, stun |
| `TeleportTo` | Instant reposition | Blink, recall |
| `SpawnEntity` | Create interactive object | Turret, wall, trap |
| `ModifyStat` | Temporary stat change | Speed boost, damage amp |
| `GrappleTo` | Pull toward point | Grapple hook, pull |
| `Shield` | Create damage-absorbing barrier | Deployable shield, personal bubble |
| `Transform` | Change hero form/state | Berserk mode, stealth |
| `Reflect` | Redirect incoming projectiles | Deflect, mirror |
| `AreaScan` | Detect entities in range | Wallhacks, sonar |

---

## 9. Configuration & Balance

### 9.1 Global Config (`sh_game_config.lua`)

```lua
ARENA.Config = {
    -- Team
    TeamSize = 6,
    TeamCount = 2,
    AllowSpectators = true,

    -- Match
    GameMode = "round_based",  -- "round_based", "koth", "payload", "deathmatch"
    RoundsToWin = 3,
    RoundTime = 180,

    -- Respawn
    RespawnTime = 5,
    RespawnWave = false,   -- If true, respawn in waves every N seconds

    -- Balance
    GlobalDamageScale = 1.0,
    GlobalHealingScale = 1.0,
    HeadshotMultiplier = 2.0,
    UltChargeRate = 1.0,

    -- Dev
    DevMode = true,         -- Enables hot-reload, debug HUD
    DebugDamage = true,     -- Print damage numbers to console
}
```

### 9.2 Dev Console Commands (for testing)

```
arena_give_hero <heroID>        -- Force switch to hero
arena_set_health <amount>       -- Set your health
arena_give_ult                  -- Fully charge ultimate
arena_god                       -- Toggle godmode
arena_reload_heroes             -- Hot-reload all hero definitions
arena_reload_hero <heroID>      -- Hot-reload specific hero
arena_spawn_dummy               -- Spawn target dummy entity
arena_set_team_size <n>         -- Change team size
arena_skip_round                -- Force end current round
arena_debug_damage <0/1>        -- Toggle damage debug output
```

---

## 10. Future Systems (Post-Milestone 1)

These are scoped out but not built in M1:

- **Hero Selection Screen** — Full VGUI with hero previews, role filters, team comp warnings
- **Objective Modes** — KOTH, Payload, Control Point (requires map entities or Lua-spawned objectives)
- **Workshop Integration** — Player model auto-assignment per hero, custom sound packs
- **Spectator System** — Free cam, player follow, ability usage overlay
- **Replay/Kill Cam** — Source demo recording + playback
- **Custom Maps** — Hammer entities for spawn rooms, objectives, arena boundaries
- **Voice Lines** — Per-hero contextual voice lines (ult callout, kill, damaged)
- **Scoreboard** — Damage dealt, healing done, objective time, K/D/A
