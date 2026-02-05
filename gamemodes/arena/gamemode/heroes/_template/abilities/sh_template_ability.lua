-- heroes/YOUR_HERO_NAME/abilities/sh_ability_name.lua
-- Template ability file. Copy and modify for each ability.

local ABILITY = ARENA.AbilityBase:New("yourhero_abilityname")

ABILITY.Name        = "Ability Name"
ABILITY.Description = "What this ability does."
ABILITY.Slot        = ARENA_SLOT_ABILITY1

-- Resource configuration
-- Types: ARENA_RESOURCE_NONE, ARENA_RESOURCE_COOLDOWN, ARENA_RESOURCE_AMMO,
--        ARENA_RESOURCE_ENERGY, ARENA_RESOURCE_CHARGES
ABILITY.Resource = {
    Type     = ARENA_RESOURCE_COOLDOWN,
    Cooldown = 8,
    -- MaxAmmo = 0, AmmoPerUse = 1, ReloadTime = 0,          -- for AMMO
    -- MaxEnergy = 0, EnergyCost = 0, EnergyRegen = 0,       -- for ENERGY
    -- MaxCharges = 0, ChargeRegenTime = 0,                   -- for CHARGES
}

-- Activation type
-- ARENA_ACTIVATION_INSTANT  — fires once on press
-- ARENA_ACTIVATION_HOLD     — active while button held, calls OnTick
-- ARENA_ACTIVATION_TOGGLE   — press on/off
-- ARENA_ACTIVATION_CHANNEL  — locks player, calls OnTick
-- ARENA_ACTIVATION_CHARGE   — hold to charge, fires on release via OnRelease
ABILITY.ActivationType = ARENA_ACTIVATION_INSTANT

-- ABILITY.Duration = 0     -- For HOLD/TOGGLE/CHANNEL (0 = unlimited)
-- ABILITY.ChargeTime = 0   -- For CHARGE type

------------------------------------------------------------
-- Lifecycle Methods (override what you need)
------------------------------------------------------------

function ABILITY:OnActivate(ply)
    if CLIENT then return end

    -- Your ability logic here. Common patterns:
    --
    -- DAMAGE:
    --   local dmg = ARENA:CreateDamageInfo()
    --   dmg.Attacker = ply
    --   dmg.Victim = target
    --   dmg.Damage = 50
    --   dmg.DamageType = ARENA.DamageTypes.BALLISTIC
    --   dmg.AbilityID = self.ID
    --   ARENA:ProcessDamage(dmg)
    --
    -- STATUS EFFECT:
    --   ARENA:ApplyStatusEffect(target, "stunned", 1.0, ply)
    --
    -- MOVEMENT:
    --   ply:SetVelocity(ply:GetAimVector() * 800)
    --
    -- HITSCAN:
    --   local tr = util.TraceLine({ start = ply:GetShootPos(),
    --       endpos = ply:GetShootPos() + ply:GetAimVector() * range, filter = ply })
end

-- function ABILITY:OnTick(ply, dt) end         -- For HOLD/TOGGLE/CHANNEL
-- function ABILITY:OnDeactivate(ply) end        -- Cleanup on deactivate
-- function ABILITY:OnRelease(ply, chargePercent) end  -- For CHARGE type

-- IMPORTANT: Uncomment and change the ID to match your ability
-- ARENA:RegisterAbility(ABILITY)
