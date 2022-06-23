include("shared.lua")
include("sh_globals.lua")
include("player_movement/shared.lua")
include("player_movement/cl_init.lua")
include("vgui/progressbars.lua")

	ATTACK_BIND = {
		[ANIM_STRIKE]="+attack",
		[ANIM_UPPERCUT]="invnext",
		[ANIM_UNDERCUT]="+zoom",
		[ANIM_THRUST]="invprev"
	}
	OTHER_BIND = {
	"+menu"
	}

	local SV_LINE_DATA = {}
	local CL_LINE_DATA = {}
	
	local CAM_DATA = {}
	CAM_DATA.drawviewer = false
	
	DRAW_CL_TRACERS = CreateConVar("ms_cl_draw_tracers", "0", true, false)
	CL_TRACER_LIFETIME = CreateConVar("ms_cl_cl_tracers_lifetime", "1", true, false)
	SV_TRACER_LIFETIME = CreateConVar("ms_cl_sv_tracers_lifetime", "1", true, false)
	
net.Receive("ms_tracer_server", function()
	local st = net.ReadVector()
	local en = net.ReadVector()
	local col = net.ReadUInt(2)
	local tag = net.ReadUInt(16)

	SV_LINE_DATA[#SV_LINE_DATA + 1] = st
	SV_LINE_DATA[#SV_LINE_DATA + 1] = en
	SV_LINE_DATA[#SV_LINE_DATA + 1] = col
	SV_LINE_DATA[#SV_LINE_DATA + 1] = tag
	
	timer.Simple(SV_TRACER_LIFETIME:GetFloat(), function()
		for i = 1, 4 do
			table.remove(SV_LINE_DATA,1)
		end
	end)
end)

local function CL_TRACER_DRAW(st,en) --this is tied to the framerate!
	CL_LINE_DATA[#CL_LINE_DATA + 1] = st
	CL_LINE_DATA[#CL_LINE_DATA + 1] = en
	
	timer.Simple(CL_TRACER_LIFETIME:GetFloat(), function()
		for i = 1, 2 do
			table.remove(CL_LINE_DATA,1)
		end
	end)
end

net.Receive("ms_stamina_update",function()
	local i = net.ReadUInt(8)
	local p = net.ReadEntity()
	p.m_iStamina = i
end)

net.Receive("ms_state_update", function()
	local p = net.ReadUInt(16)--UserID
	local s = net.ReadUInt(3)
	local a = net.ReadUInt(3)
	local r = net.ReadBool()
	local f = net.ReadBool()
	if Player(p):GetActiveWeapon() then
		local w = Player(p):GetActiveWeapon()
		w.m_flPrevState = CurTime()
		w.m_iState = s
		
		if f then
			w.m_iFlip = -1
		else
			w.m_iFlip = 1
		end
		if a != ANIM_SKIP then
			w.m_iAnim = a
		end
		w.m_bRiposting = r
		
		AnimInit(Player(p),s,a)
	end
end)

net.Receive("ms_ea_update", function()
	LocalPlayer():GetActiveWeapon().viewangles = LocalPlayer():EyeAngles()
end)

function GM:InitPostEntity()
	LocalPlayer().m_flJumpStartTime = 0
end

function AnimReset(p)
	if !IsValid(p) then return end
	for b = 0, p:GetBoneCount() do
		p:ManipulateBoneAngles(b,Angle(0,0,0))
	end
end

function AnimInit(p,s,a)
	p.m_aRHand = p:GetManipulateBoneAngles(p.m_iRHand)
	p.m_aRForearm = p:GetManipulateBoneAngles(p.m_iRForearm)
	p.m_aRUpperarm = p:GetManipulateBoneAngles(p.m_iRUpperarm)
	if s == STATE_IDLE then
		--AnimReset(p)
	elseif s == STATE_PARRY then
		AnimReset(p)
	elseif s == STATE_WINDUP then
	elseif s == STATE_RECOVERY then
		if a == ANIM_NONE then
			--AnimReset(p)
		end
	elseif s == STATE_ATTACK then
		if a == ANIM_STRIKE then
		--[[
			p:ManipulateBoneAngles(p.m_iRHand,Angle(-90,0,0))
			p:ManipulateBoneAngles(p.m_iRForearm,Angle(0,90,0))
			p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(0,90,0))
			]]
		end
	end
end

function GM:PlayerBindPress(p, bind)
	for k,v in pairs(ATTACK_BIND) do -- would do ipairs...
		if string.find(bind,v) then
			net.Start("ms_bind_attack")
				net.WriteUInt(k,3)
				net.WriteBool(p:GetActiveWeapon().m_bFlip)
			net.SendToServer()
		end
	end
	for k,v in ipairs(OTHER_BIND) do
		if bind == v then --string.find(bind,v) then --this messes with +menu and +menu_context...
			net.Start("ms_bind_other")
				net.WriteUInt(k,3)
			net.SendToServer()
		end
	end
	if string.find(bind,"+menu_context") then
		if CAM_DATA.drawviewer then -- 1P
			CAM_DATA.drawviewer = false
		else -- 3P
			CAM_DATA.drawviewer = true
		end
	end
end

concommand.Add("ms_help", function() 
	print
	[[
	Welcome to Melee Slasher.
	If you've played Chivalry or MORDHAU before you should feel at home,  
	as the gamemode mechanics makes akin to it: riposting, feinting, swing
	manipulation, etc.                                                 
	If you are new to this game genre then proceed to read below.      

	You MUST understand the core mechanic of this game - riposting.
	A riposte is performed when you parry opponent's attack AND you input
	attack right afterwards, this makes you unflinchable.   		   

	A feint is performed when you input during your weapon's windup    
	state, this may trick your opponent to input parry, making it      
	vulnerable to coming attacks.                                      

	It's important to understand the concept of swing manipulation, we 
	seperate it in two terms: accel and drag. An accel is performed    
	when your swing hits your opponent at the very initiation of it, a 
	drag is vice versa. This may catch your opponent off guard when    
	landing a hit very early or late.                                  

	You can also flip your attack side by holding your flip attack side
	button and inputting attack.
	
	Be aware that if your ping is higher than 100ms then you will indeed 
	have a hard time, there is nothing you can do about it.

	ALL BINDS:                                                         
	STRIKE           = +attack  (default: LMB)
	
	OVERHEAD STRIKE  = invnext  (default: mousescroll down)
	
	UNDERHAND STRIKE = +zoom    (default: ?, i recommend binding it to    
	your extra mouse buttons, for example, bind "mouse4" "alias +zoom")
	
	THRUST/STAB      = invprev  (default: mousescroll up)
	
	PARRY            = +attack2 (default: RMB)
	
	FEINT            = +menu    (default: Q)
	
	FLIP ATTACK SIDE = +reload  (default: R, i recommend bind it to     
	letter V, for example bind "v" "+reload", might need to restart for
	it to work.
	
	THIRDPERSON/FIRSTPERSON: +menu_context (default: C)
	
	OTHER INFO:
	A parry lasts 1/3 of a second.
	A swing lasts 0.54 of a second.
	]]
end)

function GM:PlayerTick(p, mv) -- doesn't work on maxplayers 1 !!!
	if mv:KeyDown(IN_RELOAD) then
		p:GetActiveWeapon().m_bFlip = true
	else
		p:GetActiveWeapon().m_bFlip = false
	end
end

--ACT_MP_RUN -- default anim
--ACT_HL2MP_RUN_CHARGING thrust anim
--ACT_HL2MP_RUN_PANICKED parry anim
function GM:CalcMainActivity(ply,velocity) -- REMOVED JUMPING AND LANDING
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

local PREV_ANG,PREV_ST
local function CalcViewModelRecovery(w, e, inv, rot, flip)
	local ea = LocalPlayer():EyeAngles()
	local ep = LocalPlayer():EyePos()
	local flAng = 16*(CurTime()-w.m_flPrevState)/w.Recovery
	local normal = Angle(w.AngleStrikeOffset*inv-ea[1]+PREV_ANG*inv,180+ea[2],0)
	normal:RotateAroundAxis(ea:Forward(),rot)
	local last_st = ep + normal:Forward() * (32 - flAng) + normal:Right() * 8*inv*flip
	local last_en = ep + normal:Forward() * (32 + w.Range) + normal:Right() * 8*inv*flip
	e:SetPos(last_st)
	e:SetAngles((last_st-last_en):Angle():__add(Angle(0,0,90)))
end
local function CalcViewModelSlash(w, e, inv, rot, flip)
	local ea = LocalPlayer():EyeAngles()
	local ep = LocalPlayer():EyePos()
	local flAng = (CurTime()-w.m_flPrevState)/w.Release
	local normal = Angle(w.AngleStrikeOffset*inv-ea[1]+flAng*inv,180+ea[2],0)
	normal:RotateAroundAxis(ea:Forward(),rot)
	local st = ep + normal:Forward() * 32 + normal:Right() * 8*inv*flip
	local en = ep + normal:Forward() * (32 + w.Range) + normal:Right() * 8*inv*flip
	if DRAW_CL_TRACERS:GetBool() then
		CL_TRACER_DRAW(st,en)
	end
	e:SetPos(st)
	e:SetAngles((st-en):Angle():__add(Angle(0,0,90)))
	PREV_ST = st
	PREV_ANG = flAng
end

hook.Add("CalcViewModelView","VM_Anim", function() 
	if LocalPlayer() && !LocalPlayer().CSENT && LocalPlayer():GetActiveWeapon().Model then --INIT CSENT, we could use GM:InitPostEntity() instead
		local p = LocalPlayer()
		p.CSENT = ClientsideModel(p:GetActiveWeapon().Model, RENDERGROUP_BOTH)
		p.CSENT:SetRenderMode(RENDERMODE_TRANSCOLOR)
		
		p.m_iStamina = 100
		p.m_iMaxStamina = 100
		p.m_eTarget = nil
	end
	if IsValid(LocalPlayer():GetActiveWeapon()) && LocalPlayer().CSENT then -- 1P
		local p = LocalPlayer()
		local ea = p:EyeAngles()
		local ep = p:EyePos()
		local w = p:GetActiveWeapon()
		local flip = w.m_iFlip
		local CSENT = LocalPlayer().CSENT
		local ARMS = LocalPlayer().ARMS
		if w.m_iState == STATE_IDLE then
			CSENT:SetPos(ep+ea:Forward()*16+ea:Right()*8)
			CSENT:SetAngles(Angle(ea[1]+90,ea[2],0))
		elseif w.m_iState == STATE_PARRY then
			CSENT:SetPos(ep+ea:Forward()*16)
			CSENT:SetAngles(Angle(ea[1],ea[2]-90,0))
		elseif w.m_iState == STATE_WINDUP then
			local multi = 1
			if w.m_bRiposting then
				multi = w.RiposteMulti
			end
			local flAng = (CurTime()-w.m_flPrevState)/(w.Windup*multi)
			if w.m_iAnim == ANIM_STRIKE then
				CSENT:SetPos(ep+ea:Forward()*(8-16*flAng)+ea:Right()*8*flip+ea:Up()*-8)
				CSENT:SetAngles(Angle(ea[1],ea[2]+15*flip,90))
			elseif w.m_iAnim == ANIM_UPPERCUT then
				CSENT:SetPos(ep+ea:Forward()*16+ea:Right()*(8*flip+16*flAng*flip)+ea:Up()*(16*flAng))
				CSENT:SetAngles(Angle(ea[1]+45,ea[2],0))
			elseif w.m_iAnim == ANIM_UNDERCUT then
				CSENT:SetPos(ep+ea:Forward()*(8-16*flAng)+ea:Right()*8*flip+ea:Up()*(-8-16*flAng))
				CSENT:SetAngles(Angle(ea[1]-45,ea[2],90))
			elseif w.m_iAnim == ANIM_THRUST then
				CSENT:SetPos(ep+ea:Forward()*(16-8*flAng)+ea:Up()*-8+ea:Right()*8*flip)
				CSENT:SetAngles(Angle(ea[1]-180,ea[2],0))
			end
		elseif w.m_iState == STATE_RECOVERY then
			if w.m_iAnim == ANIM_NONE then --this is just state_idle... we need this because parry goes into recovery state
				CSENT:SetPos(ep+ea:Forward()*16+ea:Right()*8)
				CSENT:SetAngles(Angle(ea[1]+90,ea[2],0))
			elseif w.m_iAnim == ANIM_STRIKE then
				CalcViewModelRecovery(w, CSENT, -1, 90*flip, flip)
			elseif w.m_iAnim == ANIM_UPPERCUT then
				CalcViewModelRecovery(w, CSENT, -1, 45*flip, flip)
			elseif w.m_iAnim == ANIM_UNDERCUT then
				CalcViewModelRecovery(w, CSENT, 1, -45*flip, flip)
			elseif w.m_iAnim == ANIM_THRUST then
				local flAng = 16*(CurTime()-w.m_flPrevState)/w.Recovery
				local normal = Angle(Angle(ea[1] + math.cos(math.rad(270*PREV_ANG/90)) * 2,ea[2] - math.sin(math.rad(270*PREV_ANG/90)) * 2*flip,0)) --iAngleFinal by default is 90.
				local last_st = ep + normal:Forward() * ( (32+6*(PREV_ANG/90))-flAng ) + normal:Up() * -8 + normal:Right() * 8*flip
				local last_en = ep + normal:Forward() * ((32 + w.Range)+6*(PREV_ANG/90)) + normal:Up() * -8 + normal:Right() * 8*flip
				CSENT:SetPos(last_st)
				CSENT:SetAngles((last_st-last_en):Angle())
			end
		elseif w.m_iState == STATE_ATTACK then
			if w.m_iAnim == ANIM_STRIKE then -- only attack anims can be here
				CalcViewModelSlash(w, CSENT, -1, 90*flip, flip)
			elseif w.m_iAnim == ANIM_UPPERCUT then
				CalcViewModelSlash(w, CSENT, -1, 45*flip, flip)
			elseif w.m_iAnim == ANIM_UNDERCUT then
				CalcViewModelSlash(w, CSENT, 1, -45*flip, flip)
			elseif w.m_iAnim == ANIM_THRUST then
				local flAng = (CurTime()-w.m_flPrevState)/w.Release
				local normal = Angle(Angle(ea[1] + math.sin(math.rad(270/(90/flAng)+90)) * 2,ea[2] - math.sin(math.rad(270/(90/flAng))) * 2*flip,0)) -- +math.cos(), -math.sin() 
				local st = ep + normal:Forward() * (32+12*(1/(90/flAng))) + normal:Up() * -8 + normal:Right() * 8*flip
				local en = ep + normal:Forward() * ((32 + w.Range)+12*(1/(90/flAng))) + normal:Up() * -8 + normal:Right() * 8*flip
				
				if DRAW_CL_TRACERS:GetBool() then
					CL_TRACER_DRAW(st,en)
				end
				CSENT:SetPos(st)
				CSENT:SetAngles((st-en):Angle())
				
				PREV_ANG = flAng
			end
		end
		
		if IsValid(p:GetEyeTrace().Entity) && p:GetEyeTrace().Entity:GetClass() == "player" then
			p.m_eTarget = p:GetEyeTrace().Entity
			else
			p.m_eTarget = nil
		end
	end
end)
hook.Add("CalcViewModelView","Player_Anim", function() 
	for _,p in ipairs(player.GetAll()) do -- 3P, might want to ipair ONLY the rendered
		if IsValid(p:GetActiveWeapon()) then
			if !p.m_iRHand then --can be faulty if playermodel is changed..
				p.m_iRHand = p:LookupBone("ValveBiped.Bip01_R_Hand")
				p.m_iRForearm = p:LookupBone("ValveBiped.Bip01_R_Forearm")
				p.m_iRUpperarm = p:LookupBone("ValveBiped.Bip01_R_UpperArm")
				p.m_flPrevAng = 0.0
			end
			local w = p:GetActiveWeapon()
			local ea = p:EyeAngles()
			--w.m_iState = w:GetDTInt(WEP_STATE)
			--w.m_iAnim = w:GetDTInt(WEP_ANIM)
			--w.m_bRiposting = w:GetDTBool(0)
			if w.m_iState == STATE_IDLE then
				if !p:GetManipulateBoneAngles(p.m_iRHand):__eq(Angle()) then -- rhand is always changed
					local flFraction = 1 - math.ease.OutCubic(math.Clamp((CurTime()-w.m_flPrevState)/w.Recovery,0,1))
					p:ManipulateBoneAngles(p.m_iRHand, p.m_aRHand:__mul(flFraction))
					p:ManipulateBoneAngles(p.m_iRForearm, p.m_aRForearm:__mul(flFraction))
					p:ManipulateBoneAngles(p.m_iRUpperarm, p.m_aRUpperarm:__mul(flFraction))
				end
			elseif w.m_iState == STATE_PARRY then
				--do nothing
			elseif w.m_iState == STATE_WINDUP then -- only attack anims can be here
					local multi = 1
					if w.m_bRiposting then
						multi = w.RiposteMulti
					end
					local flAng = math.Clamp(90/((w.Windup*multi)/(CurTime()-w.m_flPrevState)),0,90)
				if w.m_iAnim == ANIM_STRIKE then
					p:ManipulateBoneAngles(p.m_iRHand,Angle(-flAng,0,0))
					p:ManipulateBoneAngles(p.m_iRForearm,Angle(0,flAng,0))
					p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(0,flAng,0))
				elseif w.m_iAnim == ANIM_UPPERCUT then
					p:ManipulateBoneAngles(p.m_iRHand,Angle(0,-flAng,flAng))
					p:ManipulateBoneAngles(p.m_iRForearm,Angle(0,flAng,0))
					p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(flAng,0,0))
				elseif w.m_iAnim == ANIM_UNDERCUT then
					p:ManipulateBoneAngles(p.m_iRHand,Angle(0,-flAng,flAng))
					p:ManipulateBoneAngles(p.m_iRForearm,Angle(0,flAng,0))
				elseif w.m_iAnim == ANIM_THRUST then
					p:ManipulateBoneAngles(p.m_iRHand,Angle(0,0,-flAng/2))
					p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(0,flAng,0))
				end
			elseif w.m_iState == STATE_RECOVERY then
				local flFraction = 1 - math.ease.InCubic(math.Clamp((CurTime()-w.m_flPrevState)/w.Recovery,0,1))
				p:ManipulateBoneAngles(p.m_iRHand, p.m_aRHand:__mul(flFraction))
				p:ManipulateBoneAngles(p.m_iRForearm, p.m_aRForearm:__mul(flFraction))
				p:ManipulateBoneAngles(p.m_iRUpperarm, p.m_aRUpperarm:__mul(flFraction))
			elseif w.m_iState == STATE_ATTACK then
				local flAng = 0.0
				if w.m_iAnim == ANIM_STRIKE then -- only attack anims can be here
					flAng = math.Clamp((CurTime()-w.m_flPrevState)/w.Release,0,w.AngleStrike)
					p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(60*math.sin(math.rad(flAng*(4/3))),90-flAng*(4/3)+30),flAng*0.4)
				elseif w.m_iAnim == ANIM_UPPERCUT then
					flAng = math.Clamp((CurTime()-w.m_flPrevState)/w.Release,0,w.AngleStrike)
					p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(90+flAng,90-30*flAng/w.AngleStrike,120))
					--0,-90,90; 0,0,0
					--0,90,0; 0,0,0
					--90,0,0; 135;90;120
				elseif w.m_iAnim == ANIM_UNDERCUT then
					flAng = math.Clamp((CurTime()-w.m_flPrevState)/w.Release,0,w.AngleStrike)
					p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(-30*flAng/w.AngleStrike,-flAng,0))
					--0,-90,90; 0,0,0
					--0,90,0; 0,0,0
					--0,0,0; -15,-90,0; -30;-135;0; -30;-235;0
				elseif w.m_iAnim == ANIM_THRUST then
					--0,0,-90WINDUPFINAL; -100,-15,0THRUSTFINAL
					--0,0,0WINDUPFINAL; 0,90,0THRUSTFINAL
					--0,90,0WINDUPFINAL; 0,-90,0THRUSTFINAL
					flAng = (CurTime()-w.m_flPrevState)
					local pace_90 = math.Clamp(flAng/w.Release,0,90) -- a thrust will always have only 90 iterations(?)
					p:ManipulateBoneAngles(p.m_iRHand,Angle(-100*pace_90/90,-15*pace_90/90,-90+pace_90))
					p:ManipulateBoneAngles(p.m_iRForearm,Angle(0,pace_90,0))
					p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(0,90-180*pace_90/90,0))
				end
				p.m_flPrevAng = flAng
			end
		end
	end
end)

function GM:BuildUserInterface()
	self.ProgressBars = vgui.Create("ProgressBars")
end

function GM:Initialize()
	self:BuildUserInterface()
end

function GM:PostDrawOpaqueRenderables()
	for i = 1,#SV_LINE_DATA,4 do
		if SV_LINE_DATA[i+2] == 1 then
			render.DrawLine(SV_LINE_DATA[i],SV_LINE_DATA[i+1],Color(255,0,0))
		elseif SV_LINE_DATA[i+2] == 2 then
			render.DrawLine(SV_LINE_DATA[i],SV_LINE_DATA[i+1],Color(0,255,255))
		elseif SV_LINE_DATA[i+2] == 3 then
			render.DrawLine(SV_LINE_DATA[i],SV_LINE_DATA[i+1],Color(0,255,0))
		end
		
		if SV_LINE_DATA[i+4] && SV_LINE_DATA[i+7] == SV_LINE_DATA[i+3] then
			render.DrawLine(SV_LINE_DATA[i+1],SV_LINE_DATA[i+5],Color(0,255,0))
		end
	end
	for i = 1,#CL_LINE_DATA,2 do
		render.DrawLine(CL_LINE_DATA[i],CL_LINE_DATA[i+1],Color(255,255,0))
	end
end

--[[ IMMERSIVE 1P
		LocalPlayer():ManipulateBoneScale(LocalPlayer():LookupBone("ValveBiped.Bip01_Head1"),Vector(0,0,0))
			LocalPlayer():ManipulateBoneScale(LocalPlayer():LookupBone("ValveBiped.Bip01_Neck1"),Vector(0,0,0))
			LocalPlayer():ManipulateBoneScale(LocalPlayer():LookupBone("ValveBiped.Bip01_Spine4"),Vector(0,0,0))
			CAM_DATA.origin = LocalPlayer():GetBonePosition(6)+ LocalPlayer():EyeAngles():Up()*4 + LocalPlayer():EyeAngles():Forward()*-8--nil
			LocalPlayer().CSENT:SetColor(Color(255,255,255,0))
]]
function GM:CalcView(p,pos)
	if LocalPlayer().CSENT then
		if CAM_DATA.drawviewer then
			CAM_DATA.origin = LocalPlayer():GetPos() + LocalPlayer():EyeAngles():Forward()*-32 + Vector(0,0,64)
			LocalPlayer().CSENT:SetColor(Color(255,255,255,0))
		else
			CAM_DATA.origin = nil
			LocalPlayer().CSENT:SetColor(Color(255,255,255,255))
		end
		return CAM_DATA
	end
end

local forbidden_huds = {
	["CHudHealth"] = true,
	["CHudBattery"] = true,
	["CHudAmmo"] = true,
	["CHudSecondaryAmmo"] = true,
	["CHudWeaponSelection"] = true
	--["CHudGMod"] = true --can't use hudpaint...
}
hook.Add("HUDShouldDraw","HideHUD", function(name)
	if forbidden_huds[name] then
		return false
	end
end)

hook.Add("CreateMove","Turncap",function(cmd)
	local w = LocalPlayer():GetActiveWeapon()
	local viewangles = cmd:GetViewAngles()
	
	if IsValid(w) && w.viewangles && w.m_iState != STATE_RECOVERY && w.m_iState != STATE_IDLE then
	
		local maxdiff = FrameTime() * w.TurnCap
		local mindiff = -maxdiff
		local originalangles = w.viewangles
		local diffyaw = math.AngleDifference(viewangles[2], originalangles[2])
		local diffpitch = math.AngleDifference(viewangles[1], originalangles[1])
		
		viewangles[2] = math.NormalizeAngle(originalangles[2] + math.Clamp(diffyaw, mindiff, maxdiff))
		viewangles[1] = math.NormalizeAngle(originalangles[1] + math.Clamp(diffpitch, mindiff, maxdiff))
		w.viewangles = viewangles

		cmd:SetViewAngles(Angle(math.Clamp(viewangles[1],-60,60),viewangles[2],viewangles[3]))
		else
		cmd:SetViewAngles(Angle(math.Clamp(viewangles[1],-60,60),viewangles[2],viewangles[3]))
	end
end)