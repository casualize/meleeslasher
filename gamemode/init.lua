include("shared.lua")
AddCSLuaFile("shared.lua")

AddCSLuaFile("cl_init.lua")

include("zsbots/init.lua")

function GM:StaminaUpdate(ent,i,punish)
	if IsValid(ent) && ent:IsPlayer() then
		if punish then
			ent.m_flPrevStamina = CurTime() + 4
		end
		
		if i != nil then
			ent.m_iStamina = math.Clamp(i,0,ent.m_iMaxStamina)
		
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
	util.AddNetworkString("ms_ea_update")
	util.AddNetworkString("ms_bind_attack")
	util.AddNetworkString("ms_bind_other")
end

function GM:Initialize()
	
	DRAW_SV_TRACERS = CreateConVar("ms_sv_draw_tracers", "0", true, false)
	DEBUG_STATES = CreateConVar("ms_sv_debug_states", "0", true, false)
	self:AddNetworkStrings()
	DEBUG_I = 0 --state debugging
	
end

function GM:PlayerNoClip()
	return true
end

--player_mdl = {"e_archer","e_footman","e_knight","g_archer","g_footman","g_knight","peasant"}
	--p:SetModel("models/player/aoc_"..player_mdl[math.random(#player_mdl)]..".mdl")
	
function GM:PlayerSpawn(p)

	local strModel = "models/player/breen.mdl"
	local strInfo = p:GetInfo("cl_playermodel")
	for _,str in ipairs(player_manager.AllValidModels()) do
		if strInfo == str then
			strModel = strInfo
		end
	end
	p:SetModel(strModel)
	
	p:Give("weapon_ms_base")
	if p:IsBot() then p:GetActiveWeapon().Primary.Automatic = true end
	p:SetFOV(120)
	p:SetPlayerColor(Vector(math.Rand(0,0.5),math.Rand(0,0.5),math.Rand(0,0.5)))
	p:SetCanZoom(false)
	
	p:SetWalkSpeed(100)
	p:SetRunSpeed(100)
	
	--VARS--
	
	p.m_flPrevStamina = 0.0
	p.m_iStamina = 100
	p.m_iMaxStamina = 100
	
	self:StaminaUpdate(p,100)
	p.m_soundLowStamina = CreateSound(p,"player/breathe1.wav")
end

function GM:CalcMainActivity(ply,velocity) -- OVERRIDE, REMOVED JUMPING AND LANDING
	ply.CalcIdeal = ACT_MP_STAND_IDLE
	ply.CalcSeqOverride = -1

	if !( self:HandlePlayerNoClipping( ply, velocity ) ||
		self:HandlePlayerDriving( ply ) ||
		self:HandlePlayerVaulting( ply, velocity ) ||
		self:HandlePlayerSwimming( ply, velocity ) ||
		self:HandlePlayerDucking( ply, velocity ) ) then
		
		ply.CalcIdeal = ACT_MP_RUN

	end

	ply.m_bWasOnGround = ply:IsOnGround()
	ply.m_bWasNoclipping = ( ply:GetMoveType() == MOVETYPE_NOCLIP && !ply:InVehicle() )

	return ply.CalcIdeal, ply.CalcSeqOverride
end

function GM:Think()
	for _,p in ipairs(player.GetAll()) do
		if CurTime() >= p.m_flPrevStamina && p.m_iStamina < p.m_iMaxStamina then
			self:StaminaUpdate(p,p.m_iStamina + 2,false) -- terrible for net.
		end
		if CurTime() >= p.m_flPrevStamina + 4 && p:Health() < p:GetMaxHealth() then
			p:SetHealth(p:Health() + 1)
		end
		if p.m_iStamina > 20 then
			if p.m_soundLowStamina:IsPlaying() then
				p.m_soundLowStamina:Stop()
			end
		elseif p.m_iStamina <= 20 then
			if !p.m_soundLowStamina:IsPlaying() then
				p.m_soundLowStamina:Play()
			end
			if p.m_iStamina == 0 then
				p:SetHealth(0)
			end
		end
	end
end

net.Receive("ms_bind_attack", function(_,p)
	local a_state = net.ReadUInt(3)
	local flip = net.ReadBool()
	if IsValid(p:GetActiveWeapon()) then
		p:GetActiveWeapon():m_fWindup(a_state,false,flip)
	end
end)
net.Receive("ms_bind_other", function(_,p)
	local bind = net.ReadUInt(3)
	if IsValid(p:GetActiveWeapon()) then
		if bind == 1 then
			p:GetActiveWeapon():Feint()
		end
	end
end)

function GM:EntityTakeDamage(ent,info)
	if ent:GetClass() == "player" then
		if info:GetDamage() >= 10 then
			ent:EmitSound("vo/npc/male01/pain0"..math.random(8,9)..".wav",75,100,1)
		else
			ent:EmitSound("vo/npc/male01/pain0"..math.random(1,3)..".wav",75,100,1)
		end
		GAMEMODE:StaminaUpdate(ent,nil,true)
	end
end

function GM:DoPlayerDeath(p, att, info)
	p:CreateRagdoll()
	p:AddDeaths(1)
	if att:IsValid() && att != p then
		att:AddFrags(1)
	end
end