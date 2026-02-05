-- core/sh_hero_registry.lua
-- Central hero registration and lookup

ARENA.Heroes = ARENA.Heroes or {}
ARENA.Abilities = ARENA.Abilities or {}

------------------------------------------------------------
-- Hero Registration
------------------------------------------------------------

function ARENA:RegisterHero(id, heroTable)
    heroTable.ID = id
    heroTable.Abilities = heroTable.Abilities or {}
    heroTable.Passive = heroTable.Passive or nil
    heroTable.Movement = heroTable.Movement or {}

    self.Heroes[id] = heroTable
    print("[Arena] Registered hero: " .. heroTable.Name .. " (" .. id .. ")")
end

function ARENA:GetHero(id)
    return self.Heroes[id]
end

function ARENA:GetAllHeroes()
    return self.Heroes
end

------------------------------------------------------------
-- Ability Registration
------------------------------------------------------------

function ARENA:RegisterAbility(ability)
    if not ability or not ability.ID then
        ErrorNoHalt("[Arena] Attempted to register ability with no ID\n")
        return
    end

    self.Abilities[ability.ID] = ability
    print("[Arena] Registered ability: " .. ability.Name .. " (" .. ability.ID .. ")")
end

function ARENA:GetAbility(id)
    return self.Abilities[id]
end

------------------------------------------------------------
-- Player → Hero Lookup
------------------------------------------------------------

function ARENA:GetPlayerHero(ply)
    if not IsValid(ply) then return nil end

    local heroID = ply:GetNW2String("Arena_HeroID", "")
    if heroID == "" then return nil end

    return self.Heroes[heroID]
end

function ARENA:GetPlayerAbility(ply, slot)
    local hero = self:GetPlayerHero(ply)
    if not hero then return nil end

    local abilityID = hero.Abilities[slot]
    if not abilityID then return nil end

    return self.Abilities[abilityID]
end

------------------------------------------------------------
-- Hero Auto-Loader
-- Scans heroes/ subfolders and includes sh_hero.lua + abilities
------------------------------------------------------------

function ARENA:LoadHeroes()
    local heroPath = self._heroBasePath or "heroes/"
    local _, dirs = file.Find(heroPath .. "*", "LUA")

    for _, dir in ipairs(dirs or {}) do
        if dir == "_template" then continue end

        local heroFile = heroPath .. dir .. "/sh_hero.lua"

        -- Load abilities first (hero file references ability IDs)
        local abilityPath = heroPath .. dir .. "/abilities/"
        local abilityFiles = file.Find(abilityPath .. "sh_*.lua", "LUA")

        for _, af in ipairs(abilityFiles or {}) do
            local fullPath = abilityPath .. af
            if SERVER then AddCSLuaFile(fullPath) end
            include(fullPath)
        end

        -- Then load the hero definition
        if file.Exists(heroFile, "LUA") then
            if SERVER then AddCSLuaFile(heroFile) end
            include(heroFile)
        end
    end

    print("[Arena] Hero loading complete — " .. table.Count(self.Heroes) .. " heroes registered")
end
