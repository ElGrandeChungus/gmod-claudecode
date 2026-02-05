-- heroes/breaker/abilities/sh_shield_bash.lua
-- Shield Bash: Short-range cone melee attack, 50 dmg + 0.5s stun

local ABILITY = ARENA.AbilityBase:New("breaker_shield_bash")

ABILITY.Name        = "Shield Bash"
ABILITY.Description = "Melee cone attack. 50 damage and a brief stun."
ABILITY.Slot        = ARENA_SLOT_SECONDARY

ABILITY.Resource = {
    Type     = ARENA_RESOURCE_COOLDOWN,
    Cooldown = 5,
}

ABILITY.ActivationType = ARENA_ACTIVATION_INSTANT

-- Bash parameters
ABILITY.BashDamage    = 50
ABILITY.BashRange     = 128    -- Units (melee range)
ABILITY.BashAngle     = 90     -- Degrees (cone width)
ABILITY.StunDuration  = 0.5

function ABILITY:OnActivate(ply)
    if CLIENT then return end

    local pos = ply:GetShootPos()
    local forward = ply:GetAimVector()
    local halfAngle = math.cos(math.rad(self.BashAngle / 2))

    -- Find all players in cone
    for _, target in ipairs(player.GetAll()) do
        if target == ply then continue end
        if not target:Alive() then continue end

        local toTarget = (target:GetPos() + target:OBBCenter()) - pos
        local dist = toTarget:Length()

        if dist > self.BashRange then continue end

        -- Check cone angle
        local dot = forward:Dot(toTarget:GetNormalized())
        if dot < halfAngle then continue end

        -- Deal damage
        local dmg = ARENA:CreateDamageInfo()
        dmg.Attacker   = ply
        dmg.Victim     = target
        dmg.Damage     = self.BashDamage
        dmg.DamageType = ARENA.DamageTypes.MELEE
        dmg.AbilityID  = self.ID
        dmg.HeroID     = "breaker"
        dmg.Position   = target:GetPos()

        -- Knockback away from Breaker
        local knockDir = toTarget:GetNormalized()
        dmg.Knockback = knockDir * 300 + Vector(0, 0, 100)

        -- Apply stun on hit
        dmg.StatusEffects = {
            { id = "stunned", duration = self.StunDuration },
        }

        ARENA:ProcessDamage(dmg)
    end
end

ARENA:RegisterAbility(ABILITY)
