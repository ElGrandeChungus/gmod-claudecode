-- core/sh_ability_base.lua
-- Base class for all abilities. Every ability inherits from this via :New()

ARENA.AbilityBase = {}

function ARENA.AbilityBase:New(id)
    local ability = setmetatable({}, { __index = self })

    ability.ID          = id
    ability.Name        = "Unnamed Ability"
    ability.Description = ""
    ability.Slot        = ARENA_SLOT_ABILITY1

    -- Resource configuration (per-ability hybrid system)
    ability.Resource = {
        Type           = ARENA_RESOURCE_COOLDOWN,
        Cooldown       = 0,          -- Seconds (minimum reuse time for all types)
        MaxAmmo        = 0,          -- For AMMO type
        AmmoPerUse     = 1,          -- Ammo consumed per activation
        ReloadTime     = 0,          -- Seconds to reload full ammo
        MaxEnergy      = 0,          -- For ENERGY type
        EnergyCost     = 0,          -- Energy consumed per activation
        EnergyRegen    = 0,          -- Energy regenerated per second
        MaxCharges     = 0,          -- For CHARGES type
        ChargeRegenTime = 0,         -- Seconds per charge regeneration
    }

    -- Activation type
    ability.ActivationType = ARENA_ACTIVATION_INSTANT

    ability.Duration   = 0       -- For HOLD/TOGGLE/CHANNEL: max active time (0 = unlimited)
    ability.ChargeTime = 0       -- For CHARGE: time to reach full charge

    return ability
end

------------------------------------------------------------
-- Lifecycle Methods (override in ability definitions)
------------------------------------------------------------

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

-- Client-side: custom crosshair, indicators, etc.
function ARENA.AbilityBase:DrawHUD(ply) end

-- Client-side: preview/targeting indicator
function ARENA.AbilityBase:DrawTargeting(ply) end

------------------------------------------------------------
-- Resource Queries
------------------------------------------------------------

-- Check if the player has enough resource to use this ability
function ARENA.AbilityBase:HasResource(ply)
    local state = self:GetPlayerState(ply)
    local res = self.Resource

    if res.Type == ARENA_RESOURCE_NONE then
        return true
    elseif res.Type == ARENA_RESOURCE_COOLDOWN then
        return true -- cooldown check is separate
    elseif res.Type == ARENA_RESOURCE_AMMO then
        return (state.currentAmmo or 0) >= res.AmmoPerUse
    elseif res.Type == ARENA_RESOURCE_ENERGY then
        return (state.currentEnergy or 0) >= res.EnergyCost
    elseif res.Type == ARENA_RESOURCE_CHARGES then
        return (state.currentCharges or 0) >= 1
    end

    return true
end

-- Check if the ability is on cooldown
function ARENA.AbilityBase:IsOnCooldown(ply)
    local state = self:GetPlayerState(ply)
    return (state.cooldownEnd or 0) > CurTime()
end

-- Can the player activate this ability right now?
function ARENA.AbilityBase:CanActivate(ply)
    if ply:GetNW2Bool("Arena_Stunned", false) then return false end
    return self:HasResource(ply) and not self:IsOnCooldown(ply)
end

------------------------------------------------------------
-- Per-Player Ability State
-- Each player has independent resource tracking per ability
------------------------------------------------------------

function ARENA.AbilityBase:GetPlayerState(ply)
    if not IsValid(ply) then return {} end

    ply._arenaAbilityState = ply._arenaAbilityState or {}
    ply._arenaAbilityState[self.ID] = ply._arenaAbilityState[self.ID] or {}

    return ply._arenaAbilityState[self.ID]
end

function ARENA.AbilityBase:InitPlayerState(ply)
    local state = self:GetPlayerState(ply)
    local res = self.Resource

    state.cooldownEnd = 0
    state.isActive = false
    state.activateTime = 0
    state.channelStart = 0

    if res.Type == ARENA_RESOURCE_AMMO then
        state.currentAmmo = res.MaxAmmo
        state.reloading = false
        state.reloadEnd = 0
    elseif res.Type == ARENA_RESOURCE_ENERGY then
        state.currentEnergy = res.MaxEnergy
    elseif res.Type == ARENA_RESOURCE_CHARGES then
        state.currentCharges = res.MaxCharges
        state.chargeRegenTimers = {}
    end

    return state
end

------------------------------------------------------------
-- Resource Consumption & Cooldown
------------------------------------------------------------

function ARENA.AbilityBase:ConsumeResource(ply)
    local state = self:GetPlayerState(ply)
    local res = self.Resource

    if res.Type == ARENA_RESOURCE_AMMO then
        state.currentAmmo = (state.currentAmmo or 0) - res.AmmoPerUse
    elseif res.Type == ARENA_RESOURCE_ENERGY then
        state.currentEnergy = (state.currentEnergy or 0) - res.EnergyCost
    elseif res.Type == ARENA_RESOURCE_CHARGES then
        state.currentCharges = (state.currentCharges or 0) - 1
        -- Start regen timer for this charge
        self:StartChargeRegen(ply)
    end
end

function ARENA.AbilityBase:StartCooldown(ply)
    local state = self:GetPlayerState(ply)
    state.cooldownEnd = CurTime() + self.Resource.Cooldown
    self:OnCooldownStart(ply)
end

function ARENA.AbilityBase:StartChargeRegen(ply)
    local state = self:GetPlayerState(ply)
    state.chargeRegenTimers = state.chargeRegenTimers or {}

    -- Add a timer that will restore one charge
    table.insert(state.chargeRegenTimers, CurTime() + self.Resource.ChargeRegenTime)
end

------------------------------------------------------------
-- Resource Tick (called by ability executor each frame)
------------------------------------------------------------

function ARENA.AbilityBase:TickResources(ply, dt)
    local state = self:GetPlayerState(ply)
    local res = self.Resource

    -- Energy regen
    if res.Type == ARENA_RESOURCE_ENERGY and res.EnergyRegen > 0 then
        state.currentEnergy = math.min(
            res.MaxEnergy,
            (state.currentEnergy or 0) + res.EnergyRegen * dt
        )
    end

    -- Charge regen
    if res.Type == ARENA_RESOURCE_CHARGES and state.chargeRegenTimers then
        local now = CurTime()
        for i = #state.chargeRegenTimers, 1, -1 do
            if now >= state.chargeRegenTimers[i] then
                state.currentCharges = math.min(
                    res.MaxCharges,
                    (state.currentCharges or 0) + 1
                )
                table.remove(state.chargeRegenTimers, i)
            end
        end
    end

    -- Ammo reload
    if res.Type == ARENA_RESOURCE_AMMO and state.reloading then
        if CurTime() >= (state.reloadEnd or 0) then
            state.currentAmmo = res.MaxAmmo
            state.reloading = false
        end
    end
end

------------------------------------------------------------
-- Reload (for AMMO type)
------------------------------------------------------------

function ARENA.AbilityBase:StartReload(ply)
    local state = self:GetPlayerState(ply)
    if state.reloading then return end
    if (state.currentAmmo or 0) >= self.Resource.MaxAmmo then return end

    state.reloading = true
    state.reloadEnd = CurTime() + self.Resource.ReloadTime
end
