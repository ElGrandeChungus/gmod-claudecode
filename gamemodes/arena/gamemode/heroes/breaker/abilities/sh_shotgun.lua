-- heroes/breaker/abilities/sh_shotgun.lua
-- Scrap Cannon: Short-range shotgun, 8 pellets, 9 dmg each

local ABILITY = ARENA.AbilityBase:New("breaker_shotgun")

ABILITY.Name        = "Scrap Cannon"
ABILITY.Description = "Short-range shotgun blast. 8 pellets dealing 9 damage each."
ABILITY.Slot        = ARENA_SLOT_PRIMARY

ABILITY.Resource = {
    Type       = ARENA_RESOURCE_AMMO,
    Cooldown   = 0,
    MaxAmmo    = 6,
    AmmoPerUse = 1,
    ReloadTime = 1.5,
}

ABILITY.ActivationType = ARENA_ACTIVATION_INSTANT

-- Shotgun parameters
ABILITY.PelletCount   = 8
ABILITY.PelletDamage  = 9
ABILITY.Spread        = 0.08     -- Cone spread
ABILITY.Range         = 1024     -- Effective range in units
ABILITY.HeadshotMult  = true     -- Can headshot

function ABILITY:OnActivate(ply)
    if CLIENT then return end

    local shootPos = ply:GetShootPos()
    local aimVec = ply:GetAimVector()

    for i = 1, self.PelletCount do
        -- Apply spread to each pellet
        local spread = Vector(
            math.Rand(-self.Spread, self.Spread),
            math.Rand(-self.Spread, self.Spread),
            0
        )
        local dir = (aimVec + spread):GetNormalized()

        local tr = util.TraceLine({
            start = shootPos,
            endpos = shootPos + dir * self.Range,
            filter = ply,
            mask = MASK_SHOT,
        })

        if tr.Hit and IsValid(tr.Entity) and tr.Entity:IsPlayer() then
            local dmg = ARENA:CreateDamageInfo()
            dmg.Attacker   = ply
            dmg.Victim     = tr.Entity
            dmg.Damage     = self.PelletDamage
            dmg.DamageType = ARENA.DamageTypes.BALLISTIC
            dmg.AbilityID  = self.ID
            dmg.HeroID     = "breaker"
            dmg.Position   = tr.HitPos
            dmg.IsHeadshot = tr.HitGroup == HITGROUP_HEAD

            -- Light knockback per pellet
            dmg.Knockback = dir * 15

            ARENA:ProcessDamage(dmg)
        end

        -- Tracer effect (visual feedback)
        local effectData = EffectData()
        effectData:SetStart(shootPos)
        effectData:SetOrigin(tr.HitPos)
        effectData:SetEntity(ply)
        util.Effect("Tracer", effectData)
    end
end

ARENA:RegisterAbility(ABILITY)
