-- core/sv_ability_executor.lua
-- Server-only: ability activation, resource validation, tick loop

------------------------------------------------------------
-- Net Messages
------------------------------------------------------------

util.AddNetworkString("Arena_RequestAbility")
util.AddNetworkString("Arena_ReleaseAbility")
util.AddNetworkString("Arena_AbilityActivated")
util.AddNetworkString("Arena_AbilityDeactivated")
util.AddNetworkString("Arena_StatusEffectApplied")
util.AddNetworkString("Arena_StatusEffectRemoved")

------------------------------------------------------------
-- Player Ability State Tracking
------------------------------------------------------------

-- Track which abilities are currently active per player
-- ply._arenaActiveAbilities = { [abilityID] = true, ... }

function ARENA:IsAbilityActive(ply, abilityID)
    if not IsValid(ply) then return false end
    ply._arenaActiveAbilities = ply._arenaActiveAbilities or {}
    return ply._arenaActiveAbilities[abilityID] == true
end

function ARENA:SetAbilityActive(ply, abilityID, active)
    if not IsValid(ply) then return end
    ply._arenaActiveAbilities = ply._arenaActiveAbilities or {}
    ply._arenaActiveAbilities[abilityID] = active or nil
end

function ARENA:DeactivateAllAbilities(ply)
    if not IsValid(ply) then return end
    ply._arenaActiveAbilities = ply._arenaActiveAbilities or {}

    for abilityID, _ in pairs(ply._arenaActiveAbilities) do
        local ability = self:GetAbility(abilityID)
        if ability then
            ability:OnDeactivate(ply)
            local state = ability:GetPlayerState(ply)
            state.isActive = false
        end
    end

    ply._arenaActiveAbilities = {}
end

------------------------------------------------------------
-- Ability Activation Logic
------------------------------------------------------------

function ARENA:TryActivateAbility(ply, slot)
    if not IsValid(ply) or not ply:Alive() then return end

    -- God mode blocks nothing — but stunned blocks all
    if ply:GetNW2Bool("Arena_Stunned", false) then return end

    local ability = self:GetPlayerAbility(ply, slot)
    if not ability then return end

    local state = ability:GetPlayerState(ply)

    -- Handle toggle: if active, deactivate
    if ability.ActivationType == ARENA_ACTIVATION_TOGGLE and state.isActive then
        self:DeactivateAbility(ply, ability)
        return
    end

    -- Check resources and cooldown
    if not ability:CanActivate(ply) then return end

    -- Ultimate check
    if slot == ARENA_SLOT_ULTIMATE then
        if not self:ConsumeUlt(ply) then return end
    end

    -- Consume resource
    ability:ConsumeResource(ply)

    -- Mark active
    state.isActive = true
    state.activateTime = CurTime()
    self:SetAbilityActive(ply, ability.ID, true)

    -- Fire activation
    ability:OnActivate(ply)

    -- Broadcast activation to clients
    net.Start("Arena_AbilityActivated")
        net.WriteEntity(ply)
        net.WriteString(ability.ID)
        net.WriteVector(ply:GetPos())
    net.Broadcast()

    -- For INSTANT abilities, immediately start cooldown and deactivate
    if ability.ActivationType == ARENA_ACTIVATION_INSTANT then
        state.isActive = false
        self:SetAbilityActive(ply, ability.ID, false)
        if ability.Resource.Cooldown > 0 then
            ability:StartCooldown(ply)
        end
        -- Auto-reload for ammo weapons when empty
        if ability.Resource.Type == ARENA_RESOURCE_AMMO then
            if (state.currentAmmo or 0) <= 0 then
                ability:StartReload(ply)
            end
        end
    end
end

------------------------------------------------------------
-- Ability Deactivation
------------------------------------------------------------

function ARENA:DeactivateAbility(ply, ability)
    if not IsValid(ply) then return end

    local state = ability:GetPlayerState(ply)
    if not state.isActive then return end

    state.isActive = false
    self:SetAbilityActive(ply, ability.ID, false)

    ability:OnDeactivate(ply)

    -- Start cooldown after deactivation
    if ability.Resource.Cooldown > 0 then
        ability:StartCooldown(ply)
    end

    -- Broadcast deactivation
    net.Start("Arena_AbilityDeactivated")
        net.WriteEntity(ply)
        net.WriteString(ability.ID)
    net.Broadcast()
end

------------------------------------------------------------
-- Ability Release (for CHARGE type)
------------------------------------------------------------

function ARENA:ReleaseAbility(ply, slot)
    if not IsValid(ply) then return end

    local ability = self:GetPlayerAbility(ply, slot)
    if not ability then return end
    if ability.ActivationType ~= ARENA_ACTIVATION_CHARGE then return end

    local state = ability:GetPlayerState(ply)
    if not state.isActive then return end

    -- Calculate charge percentage
    local chargeTime = ability.ChargeTime
    local elapsed = CurTime() - state.activateTime
    local chargePercent = math.Clamp(elapsed / chargeTime, 0, 1)

    ability:OnRelease(ply, chargePercent)

    -- Deactivate
    state.isActive = false
    self:SetAbilityActive(ply, ability.ID, false)

    if ability.Resource.Cooldown > 0 then
        ability:StartCooldown(ply)
    end
end

------------------------------------------------------------
-- Net Receivers (client → server)
------------------------------------------------------------

net.Receive("Arena_RequestAbility", function(len, ply)
    local slot = net.ReadUInt(4)
    ARENA:TryActivateAbility(ply, slot)
end)

net.Receive("Arena_ReleaseAbility", function(len, ply)
    local slot = net.ReadUInt(4)
    ARENA:ReleaseAbility(ply, slot)
end)

------------------------------------------------------------
-- Think Loop: tick active abilities, resources, status, shield
------------------------------------------------------------

local lastThink = 0

hook.Add("Think", "Arena_AbilityTick", function()
    local now = CurTime()
    local dt = now - lastThink
    if dt <= 0 then return end
    lastThink = now

    for _, ply in ipairs(player.GetAll()) do
        if not ply:Alive() then continue end
        if ply:GetNW2String("Arena_HeroID", "") == "" then continue end

        local hero = ARENA:GetPlayerHero(ply)
        if not hero then continue end

        -- Tick each ability (resources + active ability OnTick)
        for slot, abilityID in pairs(hero.Abilities) do
            local ability = ARENA:GetAbility(abilityID)
            if not ability then continue end

            -- Tick resources (energy regen, charge regen, reload)
            ability:TickResources(ply, dt)

            -- Tick active abilities (HOLD, TOGGLE, CHANNEL)
            local state = ability:GetPlayerState(ply)
            if state.isActive then
                local actType = ability.ActivationType

                if actType == ARENA_ACTIVATION_HOLD
                or actType == ARENA_ACTIVATION_TOGGLE
                or actType == ARENA_ACTIVATION_CHANNEL then
                    ability:OnTick(ply, dt)

                    -- Check duration limit
                    if ability.Duration > 0 then
                        local elapsed = now - state.activateTime
                        if elapsed >= ability.Duration then
                            ARENA:DeactivateAbility(ply, ability)
                        end
                    end
                end

                -- Channel: check if player moved (breaks channel)
                if actType == ARENA_ACTIVATION_CHANNEL then
                    -- Channeling locks position — enforce freeze
                    -- (abilities can override this behavior)
                end
            end
        end

        -- Tick status effects
        ARENA:TickStatusEffects(ply, dt)

        -- Tick shield regeneration
        ARENA:TickShieldRegen(ply, dt)

        -- Tick passive ult charge
        ARENA:TickPassiveUltCharge(ply, dt)
    end
end)

------------------------------------------------------------
-- Input Handling: detect button presses for ability activation
------------------------------------------------------------

hook.Add("KeyPress", "Arena_AbilityKeyPress", function(ply, key)
    if ply:GetNW2String("Arena_HeroID", "") == "" then return end

    for slot, inKey in pairs(ARENA.SlotBinds) do
        if key == inKey then
            ARENA:TryActivateAbility(ply, slot)
            break
        end
    end
end)

hook.Add("KeyRelease", "Arena_AbilityKeyRelease", function(ply, key)
    if ply:GetNW2String("Arena_HeroID", "") == "" then return end

    for slot, inKey in pairs(ARENA.SlotBinds) do
        if key == inKey then
            local ability = ARENA:GetPlayerAbility(ply, slot)
            if not ability then continue end

            -- HOLD: deactivate on release
            if ability.ActivationType == ARENA_ACTIVATION_HOLD then
                local state = ability:GetPlayerState(ply)
                if state.isActive then
                    ARENA:DeactivateAbility(ply, ability)
                end
            end

            -- CHARGE: fire on release
            if ability.ActivationType == ARENA_ACTIVATION_CHARGE then
                ARENA:ReleaseAbility(ply, slot)
            end

            break
        end
    end
end)
