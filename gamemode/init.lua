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

include("shared.lua")
include("sh_globals.lua")
include("sh_animations.lua")
include("player_movement/shared.lua")
include("zsbots/init.lua")

function GM:StaminaUpdate(ent, i, punish)
	if IsValid(ent) and ent:IsPlayer() then
		ent.m_flPrevStamina = punish and CurTime() + 4 or ent.m_flPrevStamina
		if i ~= nil then
			ent.m_iStamina = math.Clamp(i, 0, ent.m_iMaxStamina)
		
			net.Start("ms_stamina_update")
				net.WriteUInt(ent:UserID(), 16)
				net.WriteUInt(ent.m_iStamina, 8)
			net.Broadcast()
		end
	end
end

-- forgive me!!!
function GM:AddNetworkStrings()
	util.AddNetworkString("ms_tracer_server")
	util.AddNetworkString("ms_stamina_update")
	util.AddNetworkString("ms_player_inflict")
	util.AddNetworkString("ms_anim_queue")
	util.AddNetworkString("ms_bind_other")
	util.AddNetworkString("ms_emote") -- sv/cl
	util.AddNetworkString("ms_damageindicator")
	util.AddNetworkString("ms_team_update")
end

function GM:Initialize()
	self:AddNetworkStrings()
	DRAW_SV_TRACERS = CreateConVar("ms_sv_debug_tracers", "0", true, false)
	DEBUG_STATES = CreateConVar("ms_sv_debug_states", "0", true, false)
end

function GM:PlayerNoClip()
	return true
end

function GM:PlayerShouldTaunt()
	return false
end

--player_mdl = {"e_archer","e_footman","e_knight","g_archer","g_footman","g_knight","peasant"}
--p:SetModel("models/player/aoc_"..player_mdl[math.random(#player_mdl)]..".mdl")
do
	local cdefault = Color(255, 255, 255)
	function GM:PlayerSpawn(p)
		local strModel = "models/player/Group02/male_0" .. math.random(4)*2 .. ".mdl"
		--p:SetBodygroup(0, 1)
		--p:SetBodygroup(1, 12)
		
		--[[
		-- This includes female models... (they have different anim)
		local strInfo = p:GetInfo("cl_playermodel")
		for _, v in pairs(player_manager.AllValidModels()) do
			if strInfo == valid then
				strModel = strInfo
			end
		end
		]]
		strModel = not strModel and table.Random(player_manager.AllValidModels()) or strModel
		p:SetModel(strModel)
		
		local tovec = GAME_TEAMCTABLE[p:Team()] ~= nil and GAME_TEAMCTABLE[p:Team()] or cdefault
		p:SetPlayerColor(Vector(tovec["r"] / 255, tovec["g"] / 255, tovec["b"] / 255))
		
		p:Give("weapon_ms_base")
		p:SetCanZoom(false)
		
		p:SetWalkSpeed(GAME_MVSPEED)
		p:SetRunSpeed(GAME_MVSPEED)
		
		p.m_flPrevStamina = 0.0
		p.m_iStamina = 100
		p.m_iMaxStamina = 100
		
		self:StaminaUpdate(p, 100)
		p.m_soundLowStamina = CreateSound(p, "player/breathe1.wav")

		-- p:SetupHands() -- Create the hands and call GM:PlayerSetHandsModel
	end
end

--[[ Choose the model for hands according to their player model.
function GM:PlayerSetHandsModel( ply, ent )
	local simplemodel = player_manager.TranslateToPlayerModelName( ply:GetModel() )
	local info = player_manager.TranslatePlayerHands( simplemodel )
	if (info) then
		ent:SetModel(info.model)
		ent:SetSkin(info.skin)
		ent:SetBodyGroups(info.body)
	end
end]]

function GM:Think()
	for _, p in ipairs(player.GetAll()) do
		if CurTime() >= p.m_flPrevStamina and p.m_iStamina < p.m_iMaxStamina then
			self:StaminaUpdate(p, p.m_iStamina + 2, false) -- terrible for net.
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
			if p.m_iStamina == 0 then
				p:SetHealth(0)
			end
		end
	end
end

net.Receive("ms_team_update", function(_, p)
	p:SetTeam(net.ReadUInt(8))
	p:Spawn()
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
	if IsValid(w) then
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

		if type(info:GetAttacker()) == "Player" then
			net.Start("ms_damageindicator")
				net.WriteUInt(ent:UserID(), 16)
				net.WriteUInt(dmg, 16)
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
	if att:IsValid() and att ~= p and type(att) == "Player" then
		att:AddFrags(1)
	end
end