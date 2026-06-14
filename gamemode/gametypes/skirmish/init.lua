GT_SKIRMISH.m_iTeamWins = {
	[TEAM_RED] = 0,
	[TEAM_BLUE] = 0
}
GT_SKIRMISH.m_iState = GT_SKIRMISH.WAITING

local function CheckTeamAlive(t)
	local t_p_alive = false
	for k, v in pairs(t) do
		if v:Alive() or not v:GetObserverMode(OBS_MODE_ROAMING) then
			t_p_alive = true
			break
		end
	end
	return t_p_alive
end
local function GetWinningTeam()
	local tr_p = team.GetPlayers(TEAM_RED)
	local tb_p = team.GetPlayers(TEAM_BLUE)
	if GT_SKIRMISH.m_iState == GT_SKIRMISH.ONGOING then
		if not CheckTeamAlive(tr_p) then
			return TEAM_BLUE
		end
		if not CheckTeamAlive(tb_p) then
			return TEAM_RED
		end
	end
	return nil
end

local nexttimeoutend = 0.0
local function syncgameinfo(w, nte, p)
	net.Start("ms_gt_skirmish_sync_gameinfo")
	net.WriteUInt(GT_SKIRMISH.m_iTeamWins[TEAM_RED], 8) -- red team score
	net.WriteUInt(GT_SKIRMISH.m_iTeamWins[TEAM_BLUE], 8) -- blue team score
	net.WriteInt(w, 8) -- which team won this round: 0 - timeout, -1 - don't report anything, TEAM_WHATEVER - the team that won
	net.WriteUInt(GT_SKIRMISH.m_iState, 8) -- state of the game
	net.WriteFloat(nte) -- next timeout end
	if p then -- in case we want to send it only to the joining player
		net.Send(p)
	else
		net.Broadcast()
	end
end

local startroundlock = false
function GT_SKIRMISH.m_fCheckIntermission()
	local tr_n = team.NumPlayers(TEAM_RED)
	local tb_n = team.NumPlayers(TEAM_BLUE)
	if tr_n >= 1 and tb_n >= 1 and GT_SKIRMISH.m_iState ~= GT_SKIRMISH.ONGOING and GT_SKIRMISH.m_iState ~= GT_SKIRMISH.ROUNDOVER then
		if not startroundlock then
			startroundlock = true
			GT_SKIRMISH.m_iState = GT_SKIRMISH.INTERMISSION
			local t_p = table.Add(team.GetPlayers(TEAM_RED), team.GetPlayers(TEAM_BLUE))
			for _, v in pairs(t_p) do -- doesn't update soon enough to freeze the last player joining
				timer.Simple(0, function() v:Spawn() end)
			end
			timer.Create("ms_IntermissionTimer", 5, 1, GT_SKIRMISH.m_fStartRound)
			nexttimeoutend = CurTime() + 5
			syncgameinfo(-1, nexttimeoutend)
		end
	elseif tr_n < 1 or tb_n < 1 then
		startroundlock = false
		timer.Remove("ms_EndRoundTimer")
		GT_SKIRMISH.m_iState = GT_SKIRMISH.WAITING
		syncgameinfo(-1, 0.0)
	end
end
function GT_SKIRMISH.m_fStartRound()
	local t_p = table.Add(team.GetPlayers(TEAM_RED), team.GetPlayers(TEAM_BLUE))
		for _, v in pairs(t_p) do
			v:UnSpectate()
		end
	GT_SKIRMISH.m_iState = GT_SKIRMISH.ONGOING
	timer.Create("ms_EndRoundTimer", GT_SKIRMISH.RoundTime, 1, function() GT_SKIRMISH.m_fEndRound(true) end) -- can't provide args to the function arg alone, wrapping it with a nameless function works though
	nexttimeoutend = CurTime() + GT_SKIRMISH.RoundTime
	syncgameinfo(-1, nexttimeoutend)
	
	GT_SKIRMISH.m_fEndRound(false) -- in case the whole team dies in intermission
end
function GT_SKIRMISH.m_fEndRound(istimeout)
	local t = GetWinningTeam()
	if not istimeout then
		if not t then return end -- if both teams are alive
		
		timer.Remove("ms_EndRoundTimer")
		GT_SKIRMISH.m_iTeamWins[t] = GT_SKIRMISH.m_iTeamWins[t] + 1
	
		if GT_SKIRMISH.m_iTeamWins[t] >= GT_SKIRMISH.MaxRoundsToWin then
			GT_SKIRMISH.m_iState = GT_SKIRMISH.GAMEOVER
		else
			GT_SKIRMISH.m_iState = GT_SKIRMISH.ROUNDOVER
		end
	else
		t = 0 -- 0 - timeout
		GT_SKIRMISH.m_iState = GT_SKIRMISH.ROUNDOVER
	end
	
	-- passes to this point if its a timeout or if someteam won
	if GT_SKIRMISH.m_iState ~= GT_SKIRMISH.GAMEOVER then
		timer.Simple(5, function()
			GT_SKIRMISH.m_iState = GT_SKIRMISH.INTERMISSION
			startroundlock = false
			GT_SKIRMISH.m_fCheckIntermission()
		end)
		nexttimeoutend = CurTime() + 5
	else
		timer.Simple(20, function()
			print("GAME IS OVER. DO SMTH.")
			-- changelevel cmd etc
		end)
		nexttimeoutend = CurTime() + 20
	end
	syncgameinfo(t, nexttimeoutend)
end

function GT_SKIRMISH.PlayerChangedTeam(p, ot, nt)
	syncgameinfo(-1, nexttimeoutend, p)
	timer.Simple(0, function() -- this hook calls too early, earlier than the "deprecated" OnPlayerChangedTeam
		if GT_SKIRMISH.m_iState == GT_SKIRMISH.ONGOING or GT_SKIRMISH.m_iState == GT_SKIRMISH.ROUNDOVER or GT_SKIRMISH.m_iState == GT_SKIRMISH.GAMEOVER then
		
		else	
			p:Spawn()
		end
	end)
end

-- this hook also calls too early for this team stuff
function GT_SKIRMISH.PlayerDisconnected(p)
	timer.Simple(0, function() GT_SKIRMISH.m_fEndRound(false) end)
end

function GT_SKIRMISH.PostPlayerDeath(p)
	GT_SKIRMISH.m_fEndRound(false)
	p:Spectate(OBS_MODE_ROAMING)
end
function GT_SKIRMISH.PlayerSpawn(p)
	if GT_SKIRMISH.m_iState == GT_SKIRMISH.INTERMISSION and p:Team() ~= TEAM_SPECTATOR then
		timer.Simple(0, function() p:Spectate(OBS_MODE_NONE) end)
	end
	GT_SKIRMISH.m_fCheckIntermission()
end

function GT_SKIRMISH.PlayerDeathThink(p)
	if p:Team() == TEAM_SPECTATOR or p:Team() == TEAM_UNASSIGNED or p:Team() == TEAM_CONNECTING then
		return false
	end
	
	if GT_SKIRMISH.m_iState == GT_SKIRMISH.INTERMISSION or GT_SKIRMISH.m_iState == GT_SKIRMISH.WAITING then
		return true
	else
		return false
	end
end