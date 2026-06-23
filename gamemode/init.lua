AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("sh_globals.lua")
AddCSLuaFile("sh_animations.lua")
AddCSLuaFile("player_movement/shared.lua")
AddCSLuaFile("player_movement/cl_init.lua")
AddCSLuaFile("cl_scoreboard.lua")
AddCSLuaFile("vgui/progressbars.lua")
AddCSLuaFile("vgui/emotepanel.lua")
AddCSLuaFile("vgui/damageindicator.lua")
AddCSLuaFile("vgui/teamselect.lua")
AddCSLuaFile("vgui/gt_skirmish.lua")
AddCSLuaFile("zsbots/shared.lua")

include("shared.lua")
include("sh_globals.lua")
include("sh_animations.lua")
include("player_movement/shared.lua")
include("zsbots/shared.lua")

AddCSLuaFile("gametypes/skirmish/cl_init.lua")
AddCSLuaFile("gametypes/skirmish/shared.lua")
include("gametypes/skirmish/shared.lua")
include("gametypes/skirmish/init.lua")

function GM:StaminaUpdate(ent, i, punish, actualpunish)
	if IsValid(ent) and ent:IsPlayer() then
		ent.m_flPrevStamina = punish and CurTime() + 4 or ent.m_flPrevStamina
		if i ~= nil then
			ent.m_iStamina = math.Clamp(i, 0, ent.m_iMaxStamina)
		
			if ent.m_iStamina <= 0 and actualpunish then -- if it works it works.
				ent:Freeze(true)
				ent:EmitSound("vo/npc/male01/pain01.wav", 75, 100, 1)
				self:StaminaUpdate(ent, 40, true)
				timer.Simple(2, function() 
					ent:Freeze(false)
				end)
				return
			end
			
			net.Start("ms_stamina_update")
				net.WriteUInt(ent:UserID(), 16)
				net.WriteUInt(ent.m_iStamina, 8)
			net.Broadcast()
		end
	end
end

function GM:AddNetworkStrings()
	util.AddNetworkString("ms_tracer_server")
	util.AddNetworkString("ms_stamina_update")
	util.AddNetworkString("ms_player_inflict")
	util.AddNetworkString("ms_anim_queue")
	util.AddNetworkString("ms_bind_other")
	util.AddNetworkString("ms_emote") -- sv/cl
	util.AddNetworkString("ms_damageindicator")
	util.AddNetworkString("ms_team_update")
	
	util.AddNetworkString("ms_sync_gametypeinfo")
	util.AddNetworkString("ms_gt_skirmish_sync_gameinfo")
end

DRAW_SV_TRACERS = CreateConVar("ms_sv_debug_tracers", "0")
PLAYERMODEL_TYPE = CreateConVar("ms_sv_playermodel_type", "burnedknight", {FCVAR_ARCHIVE}, "possible values: hl2, mbwarband, burnedknight")
DEBUG_STATES = CreateConVar("ms_sv_debug_states", "0")

GAMETYPE = "default"
GAMETYPE_CONVAR = CreateConVar("ms_sv_next_gametype", "skirmish", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "possible values: skirmish, ffa, tdm") -- shouldn't change this midgame, do it when the game is over. need a different solution
GAMETYPE = GAMETYPE_CONVAR:GetString()

function GM:Initialize()
	self:AddNetworkStrings()

	if game.SinglePlayer() then
		print("Singleplayer session detected, leave to main menu, open console and type 'maxplayers 2' or any number of players preferred and then 'map ms_contraband_v2' or any map preffered.")
	end
	
	if util.IsValidModel("models/players/PlateKnight1.mdl") == false then
		print("mbwarband playermodels arent found! fallbacking to hl2 playermodels")
		PLAYERMODEL_TYPE:SetString("hl2")
	end
	if util.IsValidModel("models/player/recon/chaosknight/ck_pm.mdl") == false then
		print("burnedknight playermodels arent found! fallbacking to hl2 playermodels")
		PLAYERMODEL_TYPE:SetString("hl2")
	end
	
	if GAMETYPE == "skirmish" then
		for _, v in ipairs({"PlayerChangedTeam", "PlayerDisconnected", "PostPlayerDeath", "PlayerSpawn", "PlayerDeathThink"}) do
			hook.Add(v, "gt_skirmish_" .. v, GT_SKIRMISH[v])
		end
	end
	
	-- unused, probably remove
	if GAMETYPE == "ffa" then
		GAME_NTEAMS = 1
	end
	if GAMETYPE == "tdm" then
		GAME_NTEAMS = 2
	end
end

hook.Add("OnPlayerJump", "ms_OnPlayerJump", function(p)
	GAMEMODE:StaminaUpdate(p, p.m_iStamina - 10, true)
end)
hook.Add("PostPlayerDeath", "ms_PostPlayerDeath", function(p)
	p:Freeze(false)
end)

function GM:OnPlayerChangedTeam()  -- this "deprecated" function was causing spectator to freely spawn into the map after team change. spent ages troubleshooting this issue
end

function GM:PlayerInitialSpawn(p)
	-- unused. started using convar sv/cl replication system instead
	net.Start("ms_sync_gametypeinfo")
		net.WriteString(GAMETYPE)
	net.Send(p)
	
	p:ConCommand( "gm_showteam" )
end

-- function GM:PlayerJoinTeam() -- might want to look into this one as well
function GM:PlayerNoClip(p)
	if p:IsSuperAdmin() then
		return true
	else
		return false
	end
end
function GM:PlayerShouldTaunt()
	return false
end
function GM:CanPlayerSuicide(p)
	if p:Team() == TEAM_SPECTATOR or p:Team() == TEAM_UNASSIGNED or p:Team() == TEAM_CONNECTING then
		return false
	else
		return true
	end
end

do
	local cdefault = Color(255, 255, 255)
	function GM:PlayerSpawn(p)
		if p:Team() == TEAM_SPECTATOR or p:Team() == TEAM_UNASSIGNED or p:Team() == TEAM_CONNECTING then
			self:PlayerSpawnAsSpectator(p) --stops new players from "suiciding" when joining a team
			p:Spectate(OBS_MODE_ROAMING)
			return
		else
			p:UnSpectate()
		end
		
		-- Female pmodels commonly use a different anim base, just to keep an eye out
		local bodygroup = "012"
		local strModel = "models/player/breen.mdl" -- default pmodel
		if PLAYERMODEL_TYPE:GetString() == "hl2" then
			strModel = "models/player/Group02/male_0" .. math.random(4)*2 .. ".mdl"
			local tovec = GAME_TEAMCTABLE[p:Team()] ~= nil and GAME_TEAMCTABLE[p:Team()] or cdefault
			p:SetPlayerColor(Vector(tovec["r"] / 255, tovec["g"] / 255, tovec["b"] / 255))
			strModel = not strModel and table.Random(player_manager.AllValidModels()) or strModel
		elseif PLAYERMODEL_TYPE:GetString() == "mbwarband" then -- pretty decent model but awful hitboxes
			strModel = "models/players/PlateKnight1.mdl"
			if p:Team() <= #GAME_MBWARBAND_TEAMMAPPING and p:Team() > 0 then
				bodygroup = GAME_MBWARBAND_TEAMMAPPING[p:Team()]
			else
				bodygroup = GAME_MBWARBAND_TEAMMAPPING[TEAM_FFA]
			end
		elseif PLAYERMODEL_TYPE:GetString() == "burnedknight" then -- perfect hitboxes but big shoulder pads
			strModel = "models/player/recon/chaosknight/ck_pm.mdl"
		end
		p:SetModel(strModel)
		if PLAYERMODEL_TYPE:GetString() == "burnedknight" then -- set color only after setting the model first
			local tc = GAME_TEAMCTABLE[p:Team()]
			local rc = Color(255, 255, 255)
			if p:Team() ~= TEAM_FFA then
				rc = Color(math.Clamp(tc.r * 10, 192, 255), math.Clamp(tc.g * 10, 192, 255), math.Clamp(tc.b * 10, 192, 255), 255)
			end
			p:SetColor(rc)
		end
		p:SetBodyGroups(bodygroup) -- set body groups only after setting the model first
		
		local strPreferredWeapon = p:GetInfo("ms_cl_preferred_weapon")
		local tablePreferredWeapon = weapons.Get(strPreferredWeapon)
		if tablePreferredWeapon and tablePreferredWeapon.IsMeleeslasherWeapon and tablePreferredWeapon.Name ~= "weapon_ms_base" then
			p:Give(strPreferredWeapon)
		else
			p:Give("weapon_ms_flamberge")
		end
		p:SetCanZoom(false)
		
		p:SetWalkSpeed(GAME_MVSPEED)
		p:SetRunSpeed(GAME_MVSPEED)
	
		p.m_flPrevStamina = 0.0
		p.m_iStamina = 100
		p.m_iMaxStamina = 100
		
		self:StaminaUpdate(p, 100)
		p.m_soundLowStamina = CreateSound(p, "player/breathe1.wav")
		
		p.m_bPlayerSpawned = true
		p:SetBodyGroups(bodygroup)
	end
end

function GM:Think()
	for _, p in ipairs(player.GetAll()) do
		if not p.m_bPlayerSpawned or not p:Alive() then continue end
		
		if CurTime() >= p.m_flPrevStamina and p.m_iStamina < p.m_iMaxStamina then
			self:StaminaUpdate(p, p.m_iStamina + 2, false)
		end
		if CurTime() >= p.m_flPrevStamina + 4 and p:Health() < p:GetMaxHealth() then
			p:SetHealth(p:Health() + 1)
		end
		if p.m_iStamina > 20 then
			if p.m_soundLowStamina:IsPlaying() then
				p.m_soundLowStamina:Stop()
			end
		elseif p.m_iStamina <= 20 then
			if not p.m_soundLowStamina:IsPlaying() then
				p.m_soundLowStamina:Play()
			end
		end
	end
end

-- no longer used. started using official implementation of team joining system
net.Receive("ms_team_update", function(_, p)
	p:SetTeam(net.ReadUInt(8))
	p:Kill()
end)
net.Receive("ms_anim_queue", function(_, p)
	local w = p:GetActiveWeapon()
	if IsValid(w) then
		w.m_iQueuedAnim = net.ReadUInt(3)
		w.m_bQueuedFlip = net.ReadBool()
	end
end)
net.Receive("ms_bind_other", function(_, p)
	local w = p:GetActiveWeapon()
	if IsValid(w) and w.IsMeleeslasherWeapon then
		if net.ReadUInt(3) == OTHER_FEINT then
			w:Feint()
		end
	end
end)
net.Receive("ms_emote", function(_, p)
	local e = net.ReadUInt(8)
	if IsValid(p:GetActiveWeapon()) and p:GetActiveWeapon().m_iState == STATE_IDLE then
		p:AddVCDSequenceToGestureSlot(GESTURE_SLOT_VCD, p:LookupSequence(DEF_EMOTE[e]), 0, true) -- Synchronize hitboxes with gestures
		net.Start("ms_emote")
			net.WriteUInt(p:UserID(), 16)
			net.WriteUInt(e, 8)
		net.Broadcast()
	end
end)

function GM:EntityTakeDamage(ent, info)
	if type(ent) == "Player" then
		local dmg = info:GetDamage()
		local dmgbonus = info:GetDamageBonus()

		if type(info:GetAttacker()) == "Player" then
			net.Start("ms_damageindicator")
				net.WriteUInt(ent:UserID(), 16)
				net.WriteUInt(dmg, 16)
				net.WriteBool(dmgbonus)
			net.Send(info:GetAttacker())
		end

		local strid = dmg >= 10 and math.random(8,9) or math.random(1,3)
		ent:EmitSound("vo/npc/male01/pain0" .. strid .. ".wav", 75, 100, 1)

		GAMEMODE:StaminaUpdate(ent, nil, true)
	end
end

function GM:DoPlayerDeath(p, att, info)
	local ref = ents.Create("prop_corpse")
	ref:SetOwner(p)
	ref:Spawn()
	
	p:AddDeaths(1)
	if att:IsValid() and type(att) == "Player" then
		if att ~= p and (att:Team() ~= p:Team() or att:Team() == TEAM_FFA) then
			att:AddFrags(1)
		else
			att:AddFrags(-1)
		end
	end
end