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

concommand.Add("ms_parrythis", function(p, cmd, args)
	if p:IsSuperAdmin() then
		if args[1] then
			local arg = tonumber(args[1])
			if type(arg) == "number" then
				if arg == -1 then
					print("e")
					local players = {}
					if GAMETYPE == "skirmish" or GAMETYPE == "tdm" then
						players = table.Add(team.GetPlayers(TEAM_RED), team.GetPlayers(TEAM_BLUE))
					elseif GAMETYPE == "ffa" then
						players = team.GetPlayers(TEAM_FFA)
					else
						return
					end
					for _, v in pairs(players) do
						v:StripWeapons()
						v:Give("weapon_357")
					end
				else
					if Player(arg):IsValid() then
						Player(arg):StripWeapons()
						Player(arg):Give("weapon_357")
					end
				end
			end
		else
			p:StripWeapons()
			p:Give("weapon_357")
		end
	end
end)