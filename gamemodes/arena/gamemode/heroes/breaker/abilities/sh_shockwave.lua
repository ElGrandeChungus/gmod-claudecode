-- heroes/breaker/abilities/sh_shockwave.lua
-- Shockwave (Ultimate): Ground slam — 150 dmg in 8m radius, heavy knockback, 1s stun

local ABILITY = ARENA.AbilityBase:New("breaker_shockwave")

ABILITY.Name        = "Shockwave"
ABILITY.Description = "Ultimate: Slam the ground, dealing 150 damage in a wide area with heavy knockback and a stun."
ABILITY.Slot        = ARENA_SLOT_ULTIMATE

ABILITY.Resource = {
    Type     = ARENA_RESOURCE_NONE,  -- Gated by ult charge, not a resource
    Cooldown = 0,
}

ABILITY.ActivationType = ARENA_ACTIVATION_INSTANT

-- Shockwave parameters
ABILITY.Damage       = 150
ABILITY.Radius       = 384   -- ~8 meters in Source units (48 units/m)
ABILITY.StunDuration = 1.0
ABILITY.KnockbackForce = 600
ABILITY.KnockupForce   = 300

function ABILITY:OnActivate(ply)
    if CLIENT then return end

    local center = ply:GetPos()

    -- Find all players in radius
    for _, target in ipairs(player.GetAll()) do
        if target == ply then continue end
        if not target:Alive() then continue end

        local dist = target:GetPos():Distance(center)
        if dist > self.Radius then continue end

        -- Damage falls off linearly with distance (100% at center, 50% at edge)
        local falloff = 1.0 - (dist / self.Radius) * 0.5

        local dmg = ARENA:CreateDamageInfo()
        dmg.Attacker   = ply
        dmg.Victim     = target
        dmg.Damage     = self.Damage * falloff
        dmg.DamageType = ARENA.DamageTypes.EXPLOSIVE
        dmg.AbilityID  = self.ID
        dmg.HeroID     = "breaker"
        dmg.Position   = center

        -- Knockback away from center + upward
        local knockDir = (target:GetPos() - center)
        if knockDir:Length() > 0 then
            knockDir:Normalize()
        else
            knockDir = Vector(0, 0, 1)
        end
        dmg.Knockback = knockDir * self.KnockbackForce * falloff
            + Vector(0, 0, self.KnockupForce * falloff)

        -- Stun
        dmg.StatusEffects = {
            { id = "stunned", duration = self.StunDuration },
        }

        ARENA:ProcessDamage(dmg)
    end

    -- Screen shake for all nearby players (visual feedback)
    util.ScreenShake(center, 10, 5, 1.5, self.Radius * 1.5)

    if ARENA.Config.DebugDamage then
        print("[Arena] " .. ply:Nick() .. " used Shockwave ultimate!")
    end
end

ARENA:RegisterAbility(ABILITY)
