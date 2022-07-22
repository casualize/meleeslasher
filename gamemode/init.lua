AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("sh_globals.lua")
AddCSLuaFile("sh_animations.lua")
AddCSLuaFile("player_movement/shared.lua")
AddCSLuaFile("player_movement/cl_init.lua")
AddCSLuaFile("vgui/progressbars.lua")

include("shared.lua")
include("sh_globals.lua")
include("sh_animations.lua")
include("player_movement/shared.lua")
include("zsbots/init.lua")

function GM:StaminaUpdate(ent,i,punish)
	if IsValid(ent) and ent:IsPlayer() then
		ent.m_flPrevStamina = punish and CurTime() + 4 or ent.m_flPrevStamina
		if i ~= nil then
			ent.m_iStamina = math.Clamp(i, 0, ent.m_iMaxStamina)
		
			net.Start("ms_stamina_update")
				net.WriteUInt(ent.m_iStamina,8)
				net.WriteEntity(ent)
			net.Broadcast()
		end
	end
end

function GM:AddNetworkStrings()
	util.AddNetworkString("ms_tracer_server")
	util.AddNetworkString("ms_stamina_update")
	util.AddNetworkString("ms_state_update")
	util.AddNetworkString("ms_inflict_player")
	util.AddNetworkString("ms_ea_update")
	util.AddNetworkString("ms_bind_attack")
	util.AddNetworkString("ms_bind_other")
end

function GM:Initialize()
	self:AddNetworkStrings()
	DRAW_SV_TRACERS = CreateConVar("ms_sv_draw_tracers", "0", true, false)
	DEBUG_STATES = CreateConVar("ms_sv_debug_states", "0", true, false)
end

function GM:PlayerNoClip()
	return true
end

--player_mdl = {"e_archer","e_footman","e_knight","g_archer","g_footman","g_knight","peasant"}
--p:SetModel("models/player/aoc_"..player_mdl[math.random(#player_mdl)]..".mdl")

function GM:PlayerSpawn(p)
	local strModel
	local strInfo = p:GetInfo("cl_playermodel")
	for k, v in pairs(player_manager.AllValidModels()) do
		if strInfo == valid then
			strModel = strInfo
		end
	end
	strModel = not strModel and table.Random(player_manager.AllValidModels()) or strModel
	p:SetModel(strModel)
	p:SetPlayerColor(Vector(math.Rand(0, 0.5), math.Rand(0, 0.5), math.Rand(0, 0.5)))
	
	p:Give("weapon_ms_base")
	p:SetFOV(120)
	p:SetCanZoom(false)
	
	p:SetWalkSpeed(GAME_MVSPEED)
	p:SetRunSpeed(GAME_MVSPEED)
	
	--VARS--
	
	p.m_flPrevStamina = 0.0
	p.m_iStamina = 100000
	p.m_iMaxStamina = 100000
	
	self:StaminaUpdate(p, 100000)
	p.m_soundLowStamina = CreateSound(p,"player/breathe1.wav")

	p:SetupHands() -- Create the hands and call GM:PlayerSetHandsModel
end

-- Choose the model for hands according to their player model.
function GM:PlayerSetHandsModel( ply, ent )
	local simplemodel = player_manager.TranslateToPlayerModelName( ply:GetModel() )
	local info = player_manager.TranslatePlayerHands( simplemodel )
	if (info) then
		ent:SetModel(info.model)
		ent:SetSkin(info.skin)
		ent:SetBodyGroups(info.body)
	end
end

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

net.Receive("ms_bind_attack", function(_, p)
	local a_state = net.ReadUInt(3)
	local flip = net.ReadBool()
	if IsValid(p:GetActiveWeapon()) then
		p:GetActiveWeapon():m_fWindup(a_state, false, flip)
	end
end)
net.Receive("ms_bind_other", function(_, p)
	local bind = net.ReadUInt(3)
	if IsValid(p:GetActiveWeapon()) then
		if bind == 1 then
			p:GetActiveWeapon():Feint()
		end
	end
end)

function GM:EntityTakeDamage(ent, info)
	if ent:GetClass() == "player" then
		local strid = info:GetDamage() >= 10 and math.random(8,9) or math.random(1,3)
		ent:EmitSound("vo/npc/male01/pain0" .. strid .. ".wav", 75, 100, 1)

		GAMEMODE:StaminaUpdate(ent,nil,true)
	end
end

function GM:DoPlayerDeath(p, att, info)
	p:CreateRagdoll()
	p:AddDeaths(1)
	if att:IsValid() and att ~= p then
		att:AddFrags(1)
	end
end