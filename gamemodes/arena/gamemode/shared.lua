-- shared.lua
-- Shared entry point: initializes the global ARENA table, loads enums and config.
-- This file is automatically included by GMod before init.lua / cl_init.lua.

ARENA = ARENA or {}

-- Versioning
ARENA.Version = "0.1.0"
ARENA.Name = "Arena"

------------------------------------------------------------
-- Load order: enums first, then config
------------------------------------------------------------

-- Enums (defines all ARENA_* globals and ARENA.SlotBinds)
include("core/sh_resource_types.lua")
include("core/sh_damage_types.lua")

-- Configuration
include("config/sh_game_config.lua")

-- Core shared systems
include("core/sh_hero_registry.lua")
include("core/sh_ability_base.lua")
include("core/sh_status_effects.lua")

print("[Arena] Shared initialization complete (v" .. ARENA.Version .. ")")
