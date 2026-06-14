-- Useful macros for the 3 file system
function INC_SERVER()
	AddCSLuaFile("shared.lua")
	AddCSLuaFile("cl_init.lua")
	include("shared.lua")
end
function INC_CLIENT()
	include("shared.lua")
end

function INC_SERVER_NO_SHARED()
	AddCSLuaFile("cl_init.lua")
end
function INC_SERVER_NO_CLIENT()
	AddCSLuaFile("shared.lua")
end

function GM:CreateTeams()
	self.TeamBased = true -- this turns false after recompile for some reason
	if GAMETYPE == "ffa" then
		 team.SetUp(TEAM_FFA, "FFA", GAME_TEAMCTABLE[TEAM_FFA], true)
	elseif GAMETYPE == "tdm" or GAMETYPE == "skirmish" then
		team.SetUp(TEAM_RED, "Red Team", GAME_TEAMCTABLE[TEAM_RED], true)
		team.SetUp(TEAM_BLUE, "Blue Team", GAME_TEAMCTABLE[TEAM_BLUE], true)
		
		team.SetSpawnPoint(TEAM_RED, "info_player_terrorist")
		team.SetSpawnPoint(TEAM_BLUE, "info_player_counterterrorist")
	end
	
	team.SetUp(TEAM_SPECTATOR, "Spectator", Color(255,255,255), true)
	team.SetSpawnPoint(TEAM_SPECTATOR, "worldspawn")
end