# CLAUDE.md — Arena (GMod Hero Shooter Gamemode)

## Project Overview

This is a Garry's Mod custom gamemode called "Arena" — a modular, data-driven hero shooter. Heroes are assembled from reusable atomic ability components. The architecture is designed so that new heroes can be defined quickly in single files using a standardized schema.

The full architecture is documented in `hero_shooter_architecture.md` at the project root. **Read it before making structural changes.**

## Tech Stack

- **Language:** Lua (Garry's Mod flavor — LuaJIT 5.1 with GMod extensions)
- **Runtime:** Garry's Mod dedicated server + client
- **No external build tools** — GMod loads Lua files directly from the gamemode directory

## Directory Structure & File Naming

The gamemode lives at `gamemodes/arena/gamemode/`.

**Prefix convention is critical and must never be violated:**
- `sh_` = **shared** (runs on both client and server, included via `AddCSLuaFile` + `include`)
- `sv_` = **server only** (only `include`'d in `init.lua`, never `AddCSLuaFile`'d)
- `cl_` = **client only** (only `AddCSLuaFile`'d from server, `include`'d in `cl_init.lua`)

**Why this matters:** Running server-only code on the client leaks game logic (security risk). Running client render code on the server will crash it. Always respect the prefix.

Key directories:
- `core/` — Framework systems (registry, base classes, combat, rounds, HUD)
- `heroes/` — One subfolder per hero, each containing `sh_hero.lua` + `abilities/` folder
- `heroes/_template/` — Copy this folder to create a new hero
- `effects/` — Visual/physical effect definitions
- `interaction/` — Effect interaction matrix (what happens when fire meets ice, etc.)
- `config/` — Game settings and balance knobs
- `content/` — Models, materials, sounds (outside gamemode/ folder)

## Global Namespace

The gamemode uses a single global table: `ARENA`. All systems hang off this table.
- `ARENA.Heroes` — Hero registry
- `ARENA.StatusEffects` — Status effect registry
- `ARENA.Interactions` — Interaction matrix
- `ARENA.Config` — Game configuration
- `ARENA.AbilityBase` — Base class for all abilities

## Core Enums

These are defined in `core/sh_resource_types.lua` and used everywhere:

```
Resource types:  ARENA_RESOURCE_NONE, ARENA_RESOURCE_COOLDOWN, ARENA_RESOURCE_AMMO, ARENA_RESOURCE_ENERGY, ARENA_RESOURCE_CHARGES
Activation types: ARENA_ACTIVATION_INSTANT, ARENA_ACTIVATION_HOLD, ARENA_ACTIVATION_TOGGLE, ARENA_ACTIVATION_CHANNEL, ARENA_ACTIVATION_CHARGE
Ability slots:   ARENA_SLOT_PRIMARY (Mouse1), ARENA_SLOT_SECONDARY (Mouse2), ARENA_SLOT_ABILITY1 (Shift), ARENA_SLOT_ABILITY2 (E), ARENA_SLOT_ULTIMATE (Q), ARENA_SLOT_PASSIVE, ARENA_SLOT_MELEE (V)
Damage types:    ARENA.DamageTypes.GENERIC, .BALLISTIC, .EXPLOSIVE, .FIRE, .ICE, .ELECTRIC, .MELEE, .TRUE
```

## Hero Definition Pattern

Every hero follows this pattern in `heroes/<hero_name>/sh_hero.lua`:
1. Create a local `HERO = {}` table
2. Set identity fields: Name, Description, Role, Icon
3. Set base stats: Health, Shield, Armor, MoveSpeed
4. Set ability bindings: map `ARENA_SLOT_*` to ability IDs
5. Optionally define Passive and Movement tables
6. Call `ARENA:RegisterHero("hero_id", HERO)` at the end

## Ability Definition Pattern

Every ability follows this pattern in `heroes/<hero_name>/abilities/sh_<ability>.lua`:
1. Create via `local ABILITY = ARENA.AbilityBase:New("unique_ability_id")`
2. Set Name, Description, Slot
3. Configure Resource table (Type, Cooldown, MaxAmmo, etc.)
4. Set ActivationType
5. Override lifecycle methods: `OnActivate(ply)`, `OnTick(ply, dt)`, `OnDeactivate(ply)`, `OnRelease(ply, chargePercent)`
6. Call `ARENA:RegisterAbility(ABILITY)` at the end

## Damage Pipeline

All damage MUST go through `ARENA:ProcessDamage(dmgInfo)`. Never call `ply:SetHealth()` directly for combat damage. Create damage info via `ARENA:CreateDamageInfo()`, populate it, and pass it to the pipeline. The pipeline handles: pre-damage hooks → interaction checks → shield absorption → armor reduction → passive modifiers → health change → knockback → status effects → ult charge → kill check.

## Networked State (NW2 Variables)

Per-player state visible to all clients uses `SetNW2*`/`GetNW2*` with the prefix `Arena_`:
`Arena_HeroID`, `Arena_Health`, `Arena_MaxHealth`, `Arena_Shield`, `Arena_MaxShield`, `Arena_Armor`, `Arena_UltCharge`, `Arena_UltReady`, `Arena_SpeedMult`, `Arena_Stunned`, `Arena_Team`

## Status Effects

Registered via `ARENA:RegisterStatusEffect(id, table)`. Each defines: Name, Duration, TickRate, StackBehavior ("refresh"/"stack"/"ignore"), MaxStacks, and lifecycle callbacks (OnApply, OnTick, OnRemove). Applied via `ARENA:ApplyStatusEffect(ply, effectID, duration, applier)`.

## Physics Verb Library

Abilities are composed from these atomic operations: `ApplyForce`, `SpawnProjectile`, `Hitscan`, `CreateZone`, `ModifyHealth`, `ApplyStatus`, `TeleportTo`, `SpawnEntity`, `ModifyStat`, `GrappleTo`, `Shield`, `Transform`, `Reflect`, `AreaScan`. When building abilities, compose from these verbs rather than writing bespoke physics code.

## Round/Match State Machine

`WARMUP → HERO_SELECT → PRE_ROUND → ROUND_ACTIVE → ROUND_END → (loop or MATCH_END)`

## Current Milestone

**Milestone 1: Breaker (Proof of Concept)**
- First playable hero: Breaker (Tank) — 250 HP, 50 Shield, 25 Armor, 220 speed
- 5 abilities: Scrap Cannon (shotgun), Shield Bash (melee+stun), Bull Rush (charge), Fortify (damage resist toggle), Shockwave (ult: AoE slam)
- Passive: Juggernaut (15% knockback reduction)
- Goal: full vertical slice — spawn as Breaker, shoot, take damage, use abilities, die, respawn

## Dev Commands (for testing)

```
arena_give_hero <heroID>     arena_set_health <amount>    arena_give_ult
arena_god                    arena_reload_heroes          arena_reload_hero <heroID>
arena_spawn_dummy            arena_set_team_size <n>      arena_skip_round
arena_debug_damage <0/1>
```

## Common Pitfalls

- **Never `AddCSLuaFile` an `sv_` file** — this sends server logic to clients
- **Never `include` a `cl_` file on the server** — client rendering code will crash the server
- **Load order matters** — enums and config must load before core systems, core before heroes
- **NW2 variables are networked to ALL clients** — don't put sensitive server state in them
- **`ply:SetHealth()` bypasses the damage pipeline** — only use for spawning/respawning, not combat
- **All ability IDs must be globally unique** — convention is `heroname_abilityname`
- **Status effect `OnRemove` must clean up properly** — especially speed multipliers (recalculate from all active effects, don't just reset to 1.0)
