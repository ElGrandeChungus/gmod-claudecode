-- cl_init.lua
-- Client entry point for the Arena gamemode
-- shared.lua is automatically included by GMod before this runs,
-- which brings in enums, config, and core shared systems.

------------------------------------------------------------
-- 1. Include shared (enums + config + core shared systems)
------------------------------------------------------------

include("shared.lua")

------------------------------------------------------------
-- 2. Heroes are already loaded via shared.lua → LoadHeroes
-- On client, only sh_ prefixed files are available
------------------------------------------------------------

-- Heroes are loaded in shared.lua via ARENA:LoadHeroes()
-- which is called from init.lua on server (with AddCSLuaFile)
-- and needs to be called here on client too
ARENA:LoadHeroes()

------------------------------------------------------------
-- 3. Client-only systems will go here (HUD, hero select, etc.)
-- Not built in Milestone 1
------------------------------------------------------------

-- include("core/cl_hud.lua")
-- include("core/cl_hero_select.lua")
-- include("core/cl_killfeed.lua")

------------------------------------------------------------
-- Net Receivers (server → client events)
------------------------------------------------------------

net.Receive("Arena_RoundStateChanged", function()
    local newState = net.ReadUInt(4)
    ARENA.CurrentState = newState
    hook.Run("Arena_MatchStateChanged", newState)
end)

net.Receive("Arena_AbilityActivated", function()
    local ply = net.ReadEntity()
    local abilityID = net.ReadString()
    local pos = net.ReadVector()
    hook.Run("Arena_AbilityActivated", ply, abilityID, pos)
end)

net.Receive("Arena_AbilityDeactivated", function()
    local ply = net.ReadEntity()
    local abilityID = net.ReadString()
    hook.Run("Arena_AbilityDeactivated", ply, abilityID)
end)

net.Receive("Arena_PlayerKilled", function()
    local victim = net.ReadEntity()
    local attacker = net.ReadEntity()
    local abilityID = net.ReadString()
    local headshot = net.ReadBool()
    hook.Run("Arena_PlayerKilled", victim, attacker, abilityID, headshot)
end)

net.Receive("Arena_HeroChanged", function()
    local ply = net.ReadEntity()
    local heroID = net.ReadString()
    hook.Run("Arena_HeroChanged", ply, heroID)
end)

net.Receive("Arena_UltReady", function()
    hook.Run("Arena_UltReady", LocalPlayer())
end)

print("[Arena] Client initialization complete")
