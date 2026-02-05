-- heroes/breaker/abilities/sh_fortify.lua
-- Fortify: Toggle self-buff. 40% damage reduction, knockback immunity, 50% move speed.

local ABILITY = ARENA.AbilityBase:New("breaker_fortify")

ABILITY.Name        = "Fortify"
ABILITY.Description = "Reduce incoming damage by 40% and become immune to knockback, but move 50% slower."
ABILITY.Slot        = ARENA_SLOT_ABILITY2

ABILITY.Resource = {
    Type     = ARENA_RESOURCE_COOLDOWN,
    Cooldown = 8,     -- Cooldown starts after deactivation
}

ABILITY.ActivationType = ARENA_ACTIVATION_TOGGLE
ABILITY.Duration = 4  -- Max duration before auto-deactivate

function ABILITY:OnActivate(ply)
    if CLIENT then return end

    -- Apply the fortified status effect (handles speed reduction)
    ARENA:ApplyStatusEffect(ply, "fortified", self.Duration, ply)

    if ARENA.Config.DebugDamage then
        print("[Arena] " .. ply:Nick() .. " activated Fortify")
    end
end

function ABILITY:OnDeactivate(ply)
    if CLIENT then return end

    -- Remove the fortified status (restores speed via recalculation)
    ARENA:RemoveStatusEffect(ply, "fortified")

    if ARENA.Config.DebugDamage then
        print("[Arena] " .. ply:Nick() .. " deactivated Fortify")
    end
end

ARENA:RegisterAbility(ABILITY)
