-- heroes/breaker/abilities/sh_charge.lua
-- Bull Rush: Charge forward ~15m, pin first enemy hit, 75 dmg on impact

local ABILITY = ARENA.AbilityBase:New("breaker_charge")

ABILITY.Name        = "Bull Rush"
ABILITY.Description = "Charge forward. First enemy hit takes 75 damage and is pinned."
ABILITY.Slot        = ARENA_SLOT_ABILITY1

ABILITY.Resource = {
    Type     = ARENA_RESOURCE_COOLDOWN,
    Cooldown = 10,
}

ABILITY.ActivationType = ARENA_ACTIVATION_HOLD
ABILITY.Duration = 0.6  -- Max charge duration in seconds

-- Charge parameters
ABILITY.ChargeSpeed   = 1200   -- Units per second
ABILITY.ChargeDamage  = 75
ABILITY.PinDuration   = 0.3    -- Brief pin after impact
ABILITY.MaxDistance    = 720    -- ~15m in Source units (48 units per meter)

function ABILITY:OnActivate(ply)
    if CLIENT then return end

    -- Store starting position and direction
    local state = self:GetPlayerState(ply)
    state.chargeStart = ply:GetPos()
    state.chargeDir = ply:GetAimVector()
    state.chargeDir.z = 0
    state.chargeDir:Normalize()
    state.chargeHit = false
    state.distanceTraveled = 0

    -- Lock aim direction during charge
    ply._arenaChargeLocked = true
end

function ABILITY:OnTick(ply, dt)
    if CLIENT then return end

    local state = self:GetPlayerState(ply)
    if state.chargeHit then
        -- Already hit someone, stop charging
        ARENA:DeactivateAbility(ply, self)
        return
    end

    -- Move the player forward
    local moveAmount = self.ChargeSpeed * dt
    state.distanceTraveled = (state.distanceTraveled or 0) + moveAmount

    -- Check max distance
    if state.distanceTraveled >= self.MaxDistance then
        ARENA:DeactivateAbility(ply, self)
        return
    end

    local velocity = state.chargeDir * self.ChargeSpeed
    ply:SetVelocity(velocity - ply:GetVelocity() + Vector(0, 0, ply:GetVelocity().z))

    -- Check for collisions with players along the charge path
    local traceStart = ply:GetPos() + Vector(0, 0, 36)
    local traceEnd = traceStart + state.chargeDir * 48

    local tr = util.TraceHull({
        start = traceStart,
        endpos = traceEnd,
        mins = Vector(-16, -16, -36),
        maxs = Vector(16, 16, 36),
        filter = ply,
        mask = MASK_PLAYERSOLID,
    })

    if tr.Hit and IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity:Alive() then
        state.chargeHit = true
        local target = tr.Entity

        -- Deal damage
        local dmg = ARENA:CreateDamageInfo()
        dmg.Attacker   = ply
        dmg.Victim     = target
        dmg.Damage     = self.ChargeDamage
        dmg.DamageType = ARENA.DamageTypes.MELEE
        dmg.AbilityID  = self.ID
        dmg.HeroID     = "breaker"
        dmg.Position   = tr.HitPos

        -- Heavy knockback in charge direction
        dmg.Knockback = state.chargeDir * 400 + Vector(0, 0, 150)

        -- Brief pin (stun)
        dmg.StatusEffects = {
            { id = "stunned", duration = self.PinDuration },
        }

        ARENA:ProcessDamage(dmg)

        -- Stop the charge
        ARENA:DeactivateAbility(ply, self)
    end

    -- Also stop if we hit a wall
    if tr.Hit and not IsValid(tr.Entity) then
        ARENA:DeactivateAbility(ply, self)
    end
end

function ABILITY:OnDeactivate(ply)
    if CLIENT then return end

    ply._arenaChargeLocked = false

    -- Kill residual velocity so the player doesn't slide
    local vel = ply:GetVelocity()
    ply:SetVelocity(Vector(0, 0, vel.z) - vel)
end

ARENA:RegisterAbility(ABILITY)
