-- core/sv_combat.lua
-- Server-only: damage pipeline, ult charge, kill tracking
-- ALL combat damage flows through ARENA:ProcessDamage()

------------------------------------------------------------
-- Net Messages
------------------------------------------------------------

util.AddNetworkString("Arena_PlayerKilled")
util.AddNetworkString("Arena_UltReady")

------------------------------------------------------------
-- Damage Info Constructor
------------------------------------------------------------

function ARENA:CreateDamageInfo()
    return {
        Attacker      = NULL,
        Victim        = NULL,
        Damage        = 0,
        DamageType    = ARENA.DamageTypes.GENERIC,
        AbilityID     = "",
        HeroID        = "",
        IsHeadshot    = false,
        IsCritical    = false,
        Knockback     = Vector(0, 0, 0),
        StatusEffects = {},         -- { {id = "burning", duration = 4}, ... }
        Position      = Vector(0, 0, 0),
    }
end

------------------------------------------------------------
-- Central Damage Processing
------------------------------------------------------------

function ARENA:ProcessDamage(dmgInfo)
    local victim = dmgInfo.Victim
    local attacker = dmgInfo.Attacker

    if not IsValid(victim) or not victim:Alive() then return end

    -- 0. Apply global damage scale
    dmgInfo.Damage = dmgInfo.Damage * self.Config.GlobalDamageScale

    -- 1. Headshot multiplier
    if dmgInfo.IsHeadshot then
        dmgInfo.Damage = dmgInfo.Damage * self.Config.HeadshotMultiplier
    end

    -- 2. Pre-damage hooks (other systems can modify dmgInfo)
    hook.Run("Arena_PreDamage", dmgInfo)

    -- 3. Attacker passive modifiers
    local atkHero = self:GetPlayerHero(attacker)
    if atkHero and atkHero.Passive and atkHero.Passive.OnDealDamage then
        atkHero.Passive.OnDealDamage(attacker, dmgInfo)
    end

    -- 4. Check interaction matrix
    self:CheckInteractions(dmgInfo)

    -- 5. Calculate final damage after resistances
    local finalDamage = dmgInfo.Damage

    -- Shield absorbs first (unless TRUE damage)
    if dmgInfo.DamageType ~= ARENA.DamageTypes.TRUE then
        local shield = victim:GetNW2Float("Arena_Shield", 0)
        if shield > 0 then
            local absorbed = math.min(shield, finalDamage)
            victim:SetNW2Float("Arena_Shield", shield - absorbed)
            finalDamage = finalDamage - absorbed
        end
    end

    -- Armor reduces remaining (diminishing returns formula, unless TRUE damage)
    if dmgInfo.DamageType ~= ARENA.DamageTypes.TRUE then
        local armor = victim:GetNW2Float("Arena_Armor", 0)
        if armor > 0 then
            finalDamage = finalDamage * (1 - (armor / (armor + 100)))
        end
    end

    -- 6. Victim passive modifiers (e.g. fortify damage reduction)
    local vicHero = self:GetPlayerHero(victim)
    if vicHero and vicHero.Passive and vicHero.Passive.OnTakeDamage then
        vicHero.Passive.OnTakeDamage(victim, dmgInfo)
    end

    -- Check for fortified status — 40% damage reduction
    if self:HasStatusEffect(victim, "fortified") then
        finalDamage = finalDamage * 0.6
    end

    -- 7. Apply damage to health
    local currentHP = victim:GetNW2Float("Arena_Health", victim:Health())
    local newHP = math.max(0, currentHP - finalDamage)
    victim:SetNW2Float("Arena_Health", newHP)
    victim:SetHealth(newHP)

    -- Reset shield regen timer on damage taken
    victim._arenaLastDamageTime = CurTime()

    -- 8. Apply knockback
    if dmgInfo.Knockback:Length() > 0 then
        victim:SetVelocity(dmgInfo.Knockback)
    end

    -- 9. Apply status effects from this hit
    for _, effect in ipairs(dmgInfo.StatusEffects) do
        self:ApplyStatusEffect(victim, effect.id, effect.duration, attacker)
    end

    -- 10. Ult charge generation for attacker
    if IsValid(attacker) and attacker:IsPlayer() then
        self:AddUltCharge(attacker, finalDamage * self.UltChargeConfig.DamageRatio)
    end

    -- 11. Debug output
    if self.Config.DebugDamage then
        local atkName = IsValid(attacker) and attacker:Nick() or "World"
        local typeName = self.DamageTypeNames[dmgInfo.DamageType] or "UNKNOWN"
        print(string.format("[Arena DMG] %s -> %s: %.1f %s (raw %.1f) [%s]",
            atkName, victim:Nick(), finalDamage, typeName, dmgInfo.Damage, dmgInfo.AbilityID))
    end

    -- 12. Post-damage hooks
    hook.Run("Arena_PostDamage", dmgInfo, finalDamage)

    -- 13. Kill check
    if newHP <= 0 then
        self:OnPlayerKilled(victim, attacker, dmgInfo)
    end
end

------------------------------------------------------------
-- Kill Handling
------------------------------------------------------------

function ARENA:OnPlayerKilled(victim, attacker, dmgInfo)
    if not IsValid(victim) then return end

    -- Broadcast kill event
    net.Start("Arena_PlayerKilled")
        net.WriteEntity(victim)
        net.WriteEntity(IsValid(attacker) and attacker or victim)
        net.WriteString(dmgInfo.AbilityID or "")
        net.WriteBool(dmgInfo.IsHeadshot or false)
    net.Broadcast()

    -- Clean up status effects
    self:RemoveAllStatusEffects(victim)

    -- Deactivate any active abilities
    self:DeactivateAllAbilities(victim)

    -- Kill the player through GMod's system
    victim:Kill()

    -- Notify round manager
    hook.Run("Arena_PlayerDied", victim, attacker, dmgInfo)

    if self.Config.DebugDamage then
        local atkName = IsValid(attacker) and attacker:Nick() or "World"
        print(string.format("[Arena] KILL: %s killed %s with %s",
            atkName, victim:Nick(), dmgInfo.AbilityID or "unknown"))
    end
end

------------------------------------------------------------
-- Ultimate Charge
------------------------------------------------------------

function ARENA:AddUltCharge(ply, amount)
    if not IsValid(ply) then return end

    local current = ply:GetNW2Float("Arena_UltCharge", 0)
    if current >= self.UltChargeConfig.MaxCharge then return end

    local new = math.Clamp(current + amount * self.Config.UltChargeRate,
        0, self.UltChargeConfig.MaxCharge)
    ply:SetNW2Float("Arena_UltCharge", new)

    if new >= self.UltChargeConfig.MaxCharge and not ply:GetNW2Bool("Arena_UltReady", false) then
        ply:SetNW2Bool("Arena_UltReady", true)
        net.Start("Arena_UltReady")
        net.Send(ply)
    end
end

function ARENA:ConsumeUlt(ply)
    if not IsValid(ply) then return false end
    if not ply:GetNW2Bool("Arena_UltReady", false) then return false end

    ply:SetNW2Float("Arena_UltCharge", 0)
    ply:SetNW2Bool("Arena_UltReady", false)
    return true
end

------------------------------------------------------------
-- Shield Regeneration (called per-player each tick)
------------------------------------------------------------

function ARENA:TickShieldRegen(ply, dt)
    if not IsValid(ply) or not ply:Alive() then return end

    local maxShield = ply:GetNW2Float("Arena_MaxShield", 0)
    if maxShield <= 0 then return end

    local currentShield = ply:GetNW2Float("Arena_Shield", 0)
    if currentShield >= maxShield then return end

    -- Don't regen if recently damaged
    local lastDmg = ply._arenaLastDamageTime or 0
    if CurTime() - lastDmg < self.Config.ShieldRegenDelay then return end

    local newShield = math.min(maxShield, currentShield + self.Config.ShieldRegenRate * dt)
    ply:SetNW2Float("Arena_Shield", newShield)
end

------------------------------------------------------------
-- Passive Ult Charge (called per-player each tick)
------------------------------------------------------------

function ARENA:TickPassiveUltCharge(ply, dt)
    if not IsValid(ply) or not ply:Alive() then return end

    self:AddUltCharge(ply, self.UltChargeConfig.PassiveRate * dt)
end

------------------------------------------------------------
-- Interaction Check (stub — full system in interaction/)
------------------------------------------------------------

function ARENA:CheckInteractions(dmgInfo)
    -- Interaction matrix will be loaded from interaction/ folder
    -- For now, this is a no-op pass-through
end

------------------------------------------------------------
-- Block GMod's default damage — all damage through our pipeline
------------------------------------------------------------

hook.Add("EntityTakeDamage", "Arena_BlockDefaultDamage", function(target, dmginfo)
    if target:IsPlayer() and target:GetNW2String("Arena_HeroID", "") ~= "" then
        dmginfo:SetDamage(0)
        dmginfo:ScaleDamage(0)
        return true
    end
end)
