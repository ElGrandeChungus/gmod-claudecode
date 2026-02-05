-- core/sv_round_manager.lua
-- Server-only: round/match state machine
-- For Milestone 1: just WARMUP and ACTIVE states

------------------------------------------------------------
-- Net Messages
------------------------------------------------------------

util.AddNetworkString("Arena_RoundStateChanged")

------------------------------------------------------------
-- State
------------------------------------------------------------

ARENA.CurrentState = ARENA_STATE_WARMUP
ARENA.RoundNumber = 0
ARENA.RoundStartTime = 0
ARENA.TeamScores = { [ARENA_TEAM_1] = 0, [ARENA_TEAM_2] = 0 }

------------------------------------------------------------
-- State Transitions
------------------------------------------------------------

function ARENA:SetMatchState(newState)
    local oldState = self.CurrentState
    self.CurrentState = newState

    -- Broadcast to clients
    net.Start("Arena_RoundStateChanged")
        net.WriteUInt(newState, 4)
    net.Broadcast()

    hook.Run("Arena_MatchStateChanged", newState, oldState)

    local stateNames = {
        [ARENA_STATE_WARMUP]      = "WARMUP",
        [ARENA_STATE_HERO_SELECT] = "HERO_SELECT",
        [ARENA_STATE_PRE_ROUND]   = "PRE_ROUND",
        [ARENA_STATE_ACTIVE]      = "ACTIVE",
        [ARENA_STATE_ROUND_END]   = "ROUND_END",
        [ARENA_STATE_MATCH_END]   = "MATCH_END",
    }

    print("[Arena] State: " .. (stateNames[newState] or "UNKNOWN"))
end

------------------------------------------------------------
-- Warmup
------------------------------------------------------------

function ARENA:StartWarmup()
    self:SetMatchState(ARENA_STATE_WARMUP)

    -- Respawn all players
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNW2String("Arena_HeroID", "") ~= "" then
            ply:Spawn()
        end
    end
end

------------------------------------------------------------
-- Start Round
------------------------------------------------------------

function ARENA:StartRound()
    self.RoundNumber = self.RoundNumber + 1
    self.RoundStartTime = CurTime()

    self:SetMatchState(ARENA_STATE_ACTIVE)

    -- Respawn all players with full health
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNW2String("Arena_HeroID", "") ~= "" then
            ply:Spawn()
        end
    end

    -- Set up round time limit
    if self.Config.RoundTime > 0 then
        timer.Create("Arena_RoundTimer", self.Config.RoundTime, 1, function()
            if ARENA.CurrentState == ARENA_STATE_ACTIVE then
                ARENA:EndRound(nil) -- nil = draw/timeout
            end
        end)
    end

    print("[Arena] Round " .. self.RoundNumber .. " started!")
end

------------------------------------------------------------
-- End Round
------------------------------------------------------------

function ARENA:EndRound(winningTeam)
    if self.CurrentState ~= ARENA_STATE_ACTIVE then return end

    timer.Remove("Arena_RoundTimer")

    self:SetMatchState(ARENA_STATE_ROUND_END)

    if winningTeam then
        self.TeamScores[winningTeam] = (self.TeamScores[winningTeam] or 0) + 1
        print("[Arena] Round " .. self.RoundNumber .. " won by team " .. winningTeam)
    else
        print("[Arena] Round " .. self.RoundNumber .. " ended in a draw")
    end

    -- Check for match win
    local roundsToWin = self.Config.RoundsToWin

    for team, score in pairs(self.TeamScores) do
        if score >= roundsToWin then
            timer.Simple(self.Config.RoundEndTime, function()
                ARENA:EndMatch(team)
            end)
            return
        end
    end

    -- Otherwise, start next round after delay
    timer.Simple(self.Config.RoundEndTime, function()
        ARENA:StartRound()
    end)
end

------------------------------------------------------------
-- End Match
------------------------------------------------------------

function ARENA:EndMatch(winningTeam)
    self:SetMatchState(ARENA_STATE_MATCH_END)

    print("[Arena] Match over! Team " .. (winningTeam or "NONE") .. " wins!")

    -- Reset after delay and start new match
    timer.Simple(10, function()
        ARENA.RoundNumber = 0
        ARENA.TeamScores = { [ARENA_TEAM_1] = 0, [ARENA_TEAM_2] = 0 }
        ARENA:StartWarmup()
    end)
end

------------------------------------------------------------
-- Respawn Handling
------------------------------------------------------------

hook.Add("Arena_PlayerDied", "Arena_RespawnTimer", function(victim, attacker, dmgInfo)
    if ARENA.CurrentState ~= ARENA_STATE_ACTIVE then return end
    if not IsValid(victim) then return end

    timer.Simple(ARENA.Config.RespawnTime, function()
        if not IsValid(victim) then return end
        if ARENA.CurrentState ~= ARENA_STATE_ACTIVE then return end
        victim:Spawn()
    end)
end)

------------------------------------------------------------
-- Dev Commands
------------------------------------------------------------

concommand.Add("arena_skip_round", function(ply, cmd, args)
    if ARENA.CurrentState == ARENA_STATE_ACTIVE then
        ARENA:EndRound(nil)
    elseif ARENA.CurrentState == ARENA_STATE_WARMUP then
        ARENA:StartRound()
    end

    local msg = "[Arena] Round skipped"
    print(msg)
    if IsValid(ply) then ply:ChatPrint(msg) end
end)

concommand.Add("arena_set_team_size", function(ply, cmd, args)
    local size = tonumber(args[1])
    if not size then
        if IsValid(ply) then ply:ChatPrint("[Arena] Usage: arena_set_team_size <n>") end
        return
    end

    ARENA.Config.TeamSize = size
    local msg = "[Arena] Team size set to " .. size
    print(msg)
    if IsValid(ply) then ply:ChatPrint(msg) end
end)

------------------------------------------------------------
-- Initialize on map load
------------------------------------------------------------

hook.Add("Initialize", "Arena_StartGamemode", function()
    print("[Arena] Gamemode initializing...")
    ARENA:StartWarmup()
end)
