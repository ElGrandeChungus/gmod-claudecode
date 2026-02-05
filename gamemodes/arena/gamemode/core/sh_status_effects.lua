-- core/sh_status_effects.lua
-- Status effect registry, application, ticking, and removal

ARENA.StatusEffects = ARENA.StatusEffects or {}

------------------------------------------------------------
-- Registration
------------------------------------------------------------

function ARENA:RegisterStatusEffect(id, effectTable)
    effectTable.ID = id
    self.StatusEffects[id] = effectTable
    print("[Arena] Registered status effect: " .. (effectTable.Name or id))
end

------------------------------------------------------------
-- Application (server only — called from combat or abilities)
------------------------------------------------------------

function ARENA:ApplyStatusEffect(ply, effectID, duration, applier)
    if CLIENT then return end
    if not IsValid(ply) then return end

    local effect = self.StatusEffects[effectID]
    if not effect then
        ErrorNoHalt("[Arena] Unknown status effect: " .. tostring(effectID) .. "\n")
        return
    end

    ply._arenaStatusEffects = ply._arenaStatusEffects or {}

    local existing = ply._arenaStatusEffects[effectID]
    local dur = duration or effect.Duration

    if existing then
        -- Handle stack behavior
        if effect.StackBehavior == "refresh" then
            existing.expireTime = CurTime() + dur
            existing.applier = applier
        elseif effect.StackBehavior == "stack" then
            if existing.stacks < (effect.MaxStacks or 1) then
                existing.stacks = existing.stacks + 1
            end
            existing.expireTime = CurTime() + dur
            existing.applier = applier
            if effect.OnApply then
                effect.OnApply(ply, existing.stacks, applier)
            end
        end
        -- "ignore" does nothing if already applied
        return
    end

    -- New application
    local entry = {
        effectID = effectID,
        stacks = 1,
        expireTime = CurTime() + dur,
        nextTick = CurTime() + (effect.TickRate or dur),
        applier = applier,
    }

    ply._arenaStatusEffects[effectID] = entry

    if effect.OnApply then
        effect.OnApply(ply, 1, applier)
    end
end

------------------------------------------------------------
-- Removal
------------------------------------------------------------

function ARENA:RemoveStatusEffect(ply, effectID)
    if CLIENT then return end
    if not IsValid(ply) then return end

    ply._arenaStatusEffects = ply._arenaStatusEffects or {}

    local existing = ply._arenaStatusEffects[effectID]
    if not existing then return end

    local effect = self.StatusEffects[effectID]
    if effect and effect.OnRemove then
        effect.OnRemove(ply)
    end

    ply._arenaStatusEffects[effectID] = nil
end

function ARENA:RemoveAllStatusEffects(ply)
    if CLIENT then return end
    if not IsValid(ply) then return end

    ply._arenaStatusEffects = ply._arenaStatusEffects or {}

    for effectID, _ in pairs(ply._arenaStatusEffects) do
        self:RemoveStatusEffect(ply, effectID)
    end
end

------------------------------------------------------------
-- Tick (called each server frame for each player)
------------------------------------------------------------

function ARENA:TickStatusEffects(ply, dt)
    if CLIENT then return end
    if not IsValid(ply) then return end

    ply._arenaStatusEffects = ply._arenaStatusEffects or {}

    local now = CurTime()
    local toRemove = {}

    for effectID, entry in pairs(ply._arenaStatusEffects) do
        -- Check expiration
        if now >= entry.expireTime then
            table.insert(toRemove, effectID)
            continue
        end

        -- Tick damage/effects
        local effect = self.StatusEffects[effectID]
        if effect and effect.TickRate and effect.OnTick then
            if now >= entry.nextTick then
                effect.OnTick(ply, entry.stacks, entry.applier)
                entry.nextTick = now + effect.TickRate
            end
        end
    end

    -- Remove expired effects
    for _, effectID in ipairs(toRemove) do
        self:RemoveStatusEffect(ply, effectID)
    end
end

------------------------------------------------------------
-- Query
------------------------------------------------------------

function ARENA:HasStatusEffect(ply, effectID)
    if not IsValid(ply) then return false end
    ply._arenaStatusEffects = ply._arenaStatusEffects or {}
    return ply._arenaStatusEffects[effectID] ~= nil
end

function ARENA:GetStatusEffectStacks(ply, effectID)
    if not IsValid(ply) then return 0 end
    ply._arenaStatusEffects = ply._arenaStatusEffects or {}
    local entry = ply._arenaStatusEffects[effectID]
    return entry and entry.stacks or 0
end

------------------------------------------------------------
-- Built-in Status Effects
------------------------------------------------------------

ARENA:RegisterStatusEffect("burning", {
    Name = "Burning",
    Duration = 4,
    TickRate = 0.5,
    StackBehavior = "refresh",
    MaxStacks = 1,
    OnApply = function(ply, stacks, applier)
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
    OnRemove = function(ply) end,
})

ARENA:RegisterStatusEffect("slowed", {
    Name = "Slowed",
    Duration = 2,
    StackBehavior = "refresh",
    MaxStacks = 1,
    OnApply = function(ply, stacks, applier)
        if SERVER then
            ARENA:RecalculateSpeedMult(ply)
        end
    end,
    OnRemove = function(ply)
        if SERVER then
            ARENA:RecalculateSpeedMult(ply)
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

ARENA:RegisterStatusEffect("fortified", {
    Name = "Fortified",
    Duration = 4,
    StackBehavior = "refresh",
    MaxStacks = 1,
    OnApply = function(ply, stacks, applier)
        if SERVER then
            ARENA:RecalculateSpeedMult(ply)
        end
    end,
    OnRemove = function(ply)
        if SERVER then
            ARENA:RecalculateSpeedMult(ply)
        end
    end,
})

------------------------------------------------------------
-- Speed Multiplier Recalculation
-- Recalculates from ALL active effects rather than naive set/reset
------------------------------------------------------------

function ARENA:RecalculateSpeedMult(ply)
    if CLIENT then return end
    if not IsValid(ply) then return end

    local mult = 1.0
    ply._arenaStatusEffects = ply._arenaStatusEffects or {}

    -- Slowed: 40% reduction
    if ply._arenaStatusEffects["slowed"] then
        mult = mult * 0.6
    end

    -- Fortified: 50% reduction
    if ply._arenaStatusEffects["fortified"] then
        mult = mult * 0.5
    end

    ply:SetNW2Float("Arena_SpeedMult", mult)
end
