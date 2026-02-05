-- init.lua
-- Server entry point for the Arena gamemode
-- Load order: shared (enums/config/core) → server systems → heroes

------------------------------------------------------------
-- 1. Send shared files to clients (AddCSLuaFile)
------------------------------------------------------------

-- Shared entry point (loads enums, config, core shared systems)
AddCSLuaFile("shared.lua")

-- Client entry point
AddCSLuaFile("cl_init.lua")

-- Shared enums and config
AddCSLuaFile("core/sh_resource_types.lua")
AddCSLuaFile("core/sh_damage_types.lua")
AddCSLuaFile("config/sh_game_config.lua")

-- Shared core systems
AddCSLuaFile("core/sh_hero_registry.lua")
AddCSLuaFile("core/sh_ability_base.lua")
AddCSLuaFile("core/sh_status_effects.lua")

------------------------------------------------------------
-- 2. Include shared (runs enums + config + core shared on server)
------------------------------------------------------------

include("shared.lua")

------------------------------------------------------------
-- 3. Include server-only systems
-- NOTE: These are NEVER AddCSLuaFile'd — server only!
------------------------------------------------------------

include("core/sv_combat.lua")
include("core/sv_hero_manager.lua")
include("core/sv_ability_executor.lua")
include("core/sv_round_manager.lua")

------------------------------------------------------------
-- 4. Load all heroes (shared — AddCSLuaFile + include)
-- This scans heroes/*/ and loads abilities + hero definitions
------------------------------------------------------------

ARENA:LoadHeroes()

print("[Arena] Server initialization complete")
