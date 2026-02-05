-- core/sv_hero_manager.lua
-- Server-only: hero assignment, player spawning, NW2 state setup

------------------------------------------------------------
-- Net Messages
------------------------------------------------------------

util.AddNetworkString("Arena_HeroChanged")
util.AddNetworkString("Arena_SelectHero")

------------------------------------------------------------
-- Assign Hero to Player
------------------------------------------------------------

function ARENA:AssignHero(ply, heroID)
    if not IsValid(ply) then return false end

    local hero = self:GetHero(heroID)
    if not hero then
        ErrorNoHalt("[Arena] Tried to assign unknown hero: " .. tostring(heroID) .. "\n")
        return false
    end

    -- Clean up old hero state
    local oldHeroID = ply:GetNW2String("Arena_HeroID", "")
    if oldHeroID ~= "" then
        self:RemoveAllStatusEffects(ply)
        self:DeactivateAllAbilities(ply)
    end

    -- Set hero identity
    ply:SetNW2String("Arena_HeroID", heroID)

    -- Set base stats via NW2
    ply:SetNW2Float("Arena_MaxHealth", hero.Health)
    ply:SetNW2Float("Arena_Health", hero.Health)
    ply:SetNW2Float("Arena_MaxShield", hero.Shield or 0)
    ply:SetNW2Float("Arena_Shield", hero.Shield or 0)
    ply:SetNW2Float("Arena_Armor", hero.Armor or 0)
    ply:SetNW2Float("Arena_SpeedMult", 1.0)
    ply:SetNW2Bool("Arena_Stunned", false)

    -- Set GMod health to match
    ply:SetHealth(hero.Health)
    ply:SetMaxHealth(hero.Health)

    -- Set walk speed
    ply:SetWalkSpeed(hero.MoveSpeed or 220)
    ply:SetRunSpeed(hero.MoveSpeed or 220)  -- No sprint in arena shooter

    -- Initialize ability states
    for slot, abilityID in pairs(hero.Abilities) do
        local ability = self:GetAbility(abilityID)
        if ability then
            ability:InitPlayerState(ply)
        end
    end

    -- Reset ult charge
    ply:SetNW2Float("Arena_UltCharge", 0)
    ply:SetNW2Bool("Arena_UltReady", false)

    -- Clear damage timer
    ply._arenaLastDamageTime = 0

    -- Broadcast hero change
    net.Start("Arena_HeroChanged")
        net.WriteEntity(ply)
        net.WriteString(heroID)
    net.Broadcast()

    print("[Arena] " .. ply:Nick() .. " assigned hero: " .. hero.Name)
    return true
end

------------------------------------------------------------
-- Player Spawn Setup
------------------------------------------------------------

function ARENA:SetupPlayerSpawn(ply)
    if not IsValid(ply) then return end

    local heroID = ply:GetNW2String("Arena_HeroID", "")
    if heroID == "" then return end

    local hero = self:GetHero(heroID)
    if not hero then return end

    -- Restore health/shield to max
    ply:SetNW2Float("Arena_Health", hero.Health)
    ply:SetNW2Float("Arena_Shield", hero.Shield or 0)
    ply:SetHealth(hero.Health)
    ply:SetMaxHealth(hero.Health)

    -- Reset speed
    ply:SetWalkSpeed(hero.MoveSpeed or 220)
    ply:SetRunSpeed(hero.MoveSpeed or 220)
    ply:SetNW2Float("Arena_SpeedMult", 1.0)

    -- Clear status effects and stun
    self:RemoveAllStatusEffects(ply)
    ply:SetNW2Bool("Arena_Stunned", false)

    -- Re-initialize ability states
    for slot, abilityID in pairs(hero.Abilities) do
        local ability = self:GetAbility(abilityID)
        if ability then
            ability:InitPlayerState(ply)
        end
    end

    -- Clear damage timer
    ply._arenaLastDamageTime = 0

    -- Strip default weapons — abilities replace weapons
    ply:StripWeapons()

    -- Give the arena hands weapon (so the player model renders hands)
    ply:Give("gmod_hands")
end

------------------------------------------------------------
-- Hero Select Request (from client)
------------------------------------------------------------

net.Receive("Arena_SelectHero", function(len, ply)
    local heroID = net.ReadString()

    if not ARENA:GetHero(heroID) then
        ply:ChatPrint("[Arena] Unknown hero: " .. heroID)
        return
    end

    ARENA:AssignHero(ply, heroID)
    ply:Spawn()
end)

------------------------------------------------------------
-- Player Movement (apply speed multiplier from status effects)
------------------------------------------------------------

hook.Add("Move", "Arena_ApplySpeedMult", function(ply, mv)
    local heroID = ply:GetNW2String("Arena_HeroID", "")
    if heroID == "" then return end

    local hero = ARENA:GetHero(heroID)
    if not hero then return end

    local speedMult = ply:GetNW2Float("Arena_SpeedMult", 1.0)
    if speedMult ~= 1.0 then
        local baseSpeed = hero.MoveSpeed or 220
        mv:SetMaxClientSpeed(baseSpeed * speedMult)
        mv:SetMaxSpeed(baseSpeed * speedMult)
    end

    -- Custom movement callback
    if hero.Movement and hero.Movement.CustomMove then
        hero.Movement.CustomMove(ply, mv)
    end
end)

------------------------------------------------------------
-- Player Initial Spawn
------------------------------------------------------------

hook.Add("PlayerInitialSpawn", "Arena_InitialSpawn", function(ply)
    -- Default to spectator team until they pick a hero
    ply:SetNW2Int("Arena_Team", ARENA_TEAM_SPECTATOR)
    ply:SetNW2String("Arena_HeroID", "")

    -- In dev mode, auto-assign first hero for quick testing
    if ARENA.Config.DevMode then
        timer.Simple(1, function()
            if not IsValid(ply) then return end
            -- Get first available hero
            for id, hero in pairs(ARENA.Heroes) do
                ARENA:AssignHero(ply, id)
                break
            end
        end)
    end
end)

hook.Add("PlayerSpawn", "Arena_PlayerSpawn", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        ARENA:SetupPlayerSpawn(ply)
    end)
end)

------------------------------------------------------------
-- Dev Commands
------------------------------------------------------------

concommand.Add("arena_give_hero", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local heroID = args[1]
    if not heroID then
        ply:ChatPrint("[Arena] Usage: arena_give_hero <heroID>")
        return
    end

    if ARENA:AssignHero(ply, heroID) then
        ply:Spawn()
        ply:ChatPrint("[Arena] Switched to " .. heroID)
    else
        ply:ChatPrint("[Arena] Unknown hero: " .. heroID)
    end
end)

concommand.Add("arena_set_health", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local amount = tonumber(args[1])
    if not amount then
        ply:ChatPrint("[Arena] Usage: arena_set_health <amount>")
        return
    end

    ply:SetHealth(amount)
    ply:SetNW2Float("Arena_Health", amount)
    ply:ChatPrint("[Arena] Health set to " .. amount)
end)

concommand.Add("arena_give_ult", function(ply, cmd, args)
    if not IsValid(ply) then return end
    ply:SetNW2Float("Arena_UltCharge", ARENA.UltChargeConfig.MaxCharge)
    ply:SetNW2Bool("Arena_UltReady", true)
    ply:ChatPrint("[Arena] Ultimate charged!")
end)

concommand.Add("arena_god", function(ply, cmd, args)
    if not IsValid(ply) then return end
    ply._arenaGodMode = not ply._arenaGodMode
    ply:ChatPrint("[Arena] God mode: " .. (ply._arenaGodMode and "ON" or "OFF"))
end)

concommand.Add("arena_reload_heroes", function(ply, cmd, args)
    ARENA.Heroes = {}
    ARENA.Abilities = {}
    ARENA:LoadHeroes()

    local msg = "[Arena] All heroes reloaded"
    print(msg)
    if IsValid(ply) then ply:ChatPrint(msg) end
end)

concommand.Add("arena_reload_hero", function(ply, cmd, args)
    local heroID = args[1]
    if not heroID then
        if IsValid(ply) then ply:ChatPrint("[Arena] Usage: arena_reload_hero <heroID>") end
        return
    end

    -- Remove existing registration
    ARENA.Heroes[heroID] = nil

    -- Re-include hero files
    local heroPath = "heroes/" .. heroID .. "/"
    local abilityPath = heroPath .. "abilities/"

    local abilityFiles = file.Find(abilityPath .. "sh_*.lua", "LUA")
    for _, af in ipairs(abilityFiles or {}) do
        include(abilityPath .. af)
    end

    local heroFile = heroPath .. "sh_hero.lua"
    if file.Exists(heroFile, "LUA") then
        include(heroFile)
    end

    local msg = "[Arena] Reloaded hero: " .. heroID
    print(msg)
    if IsValid(ply) then ply:ChatPrint(msg) end
end)

concommand.Add("arena_debug_damage", function(ply, cmd, args)
    local val = tonumber(args[1])
    if val == nil then
        ARENA.Config.DebugDamage = not ARENA.Config.DebugDamage
    else
        ARENA.Config.DebugDamage = val ~= 0
    end

    local msg = "[Arena] Damage debug: " .. (ARENA.Config.DebugDamage and "ON" or "OFF")
    print(msg)
    if IsValid(ply) then ply:ChatPrint(msg) end
end)

concommand.Add("arena_spawn_dummy", function(ply, cmd, args)
    if not IsValid(ply) then return end

    local tr = ply:GetEyeTrace()
    local dummy = ents.Create("prop_physics")
    dummy:SetModel("models/citizen_extra/male_07.mdl")
    dummy:SetPos(tr.HitPos + Vector(0, 0, 36))
    dummy:Spawn()
    dummy:SetHealth(1000)

    ply:ChatPrint("[Arena] Dummy spawned")
end)
