include("shared.lua")
include("sh_globals.lua")
include("sh_animations.lua")
include("player_movement/shared.lua")
include("player_movement/cl_init.lua")
include("vgui/progressbars.lua")
include("vgui/emotepanel.lua")
include("vgui/damageindicator.lua")

ATTACK_BIND = {
	[ANIM_STRIKE]= "+attack",
	[ANIM_UPPERCUT]= "invnext",
	[ANIM_UNDERCUT]= "+zoom",
	[ANIM_THRUST]= "invprev"
}
OTHER_BIND = {
	[1] = "+menu"
}
CLIENT_BIND = {
	[1] = "gmod_undo"
}

ENABLE_CSENT = CreateConVar("ms_cl_enable_csent", "0", true, false)
CL_DRAW_TRACERS = CreateConVar("ms_cl_draw_tracers", "0", true, false)
CL_TRACER_LIFETIME = CreateConVar("ms_cl_cl_tracers_lifetime", "1", true, false)
SV_TRACER_LIFETIME = CreateConVar("ms_cl_sv_tracers_lifetime", "1", true, false)

local CL_LINE_DATA = {}
local SV_LINE_DATA = {}

-- Rewrite this
net.Receive("ms_tracer_server", function()
	do
		local st = net.ReadVector()
		local en = net.ReadVector()
		local col = net.ReadUInt(2)
		local tag = net.ReadUInt(16)

		SV_LINE_DATA[#SV_LINE_DATA + 1] = st
		SV_LINE_DATA[#SV_LINE_DATA + 1] = en
		SV_LINE_DATA[#SV_LINE_DATA + 1] = col
		SV_LINE_DATA[#SV_LINE_DATA + 1] = tag
	end
	timer.Simple(SV_TRACER_LIFETIME:GetFloat(), function()
		for i = 1, 4 do
			table.remove(SV_LINE_DATA,1)
		end
	end)
end)

net.Receive("ms_stamina_update",function()
	local i = net.ReadUInt(8)
	local p = net.ReadEntity()
	p.m_iStamina = i
end)

net.Receive("ms_state_update", function()
	local p = net.ReadUInt(16) -- UserID
	local s = net.ReadUInt(3)
	local a = net.ReadUInt(3)
	local r = net.ReadBool()
	local f = net.ReadBool()
	if Player(p):GetActiveWeapon() then
		local w = Player(p):GetActiveWeapon()
		w.m_flPrevState = CurTime()
		w.m_iState		= s
		w.m_iAnim		= a
		w.m_bRiposting	= r
		w.m_iFlip		= f and -1 or 1 -- Converts from bool to number for arithmetic purpose
		AnimInit(Player(p))
	end
end)

net.Receive("ms_inflict_player", function()
	local p = net.ReadUInt(16) -- UserID
	Player(p):AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_PHYSICS, true)
end)

net.Receive("ms_emote", function()
	local p = net.ReadUInt(16) -- UserID
	local e = net.ReadUInt(8)
	Player(p):AddVCDSequenceToGestureSlot(0, Player(p):LookupSequence(DEF_EMOTE[e]), 0, true)
end)

net.Receive("ms_ea_update", function()
	LocalPlayer():GetActiveWeapon().viewangles = LocalPlayer():EyeAngles()
end)

-- ?
function GM:InitPostEntity()
	LocalPlayer().m_flJumpStartTime = 0
end

do
	-- Define the custom gestures set from *_anm.mdl, the mdl had to be overriden to save the hassle (can't just do another animation mdl without $includemodel'ing every pmdl eitherway)
	local defseq = {
		[STATE_IDLE] = {nil},
		[STATE_PARRY] = {"ms_parry"},
		[STATE_WINDUP] = {
			[ANIM_NONE] = nil,
			[ANIM_STRIKE] = "ms_windup_strike",
			[ANIM_UPPERCUT] = "ms_windup_uppercut",
			[ANIM_UNDERCUT] = "ms_windup_undercut",
			[ANIM_THRUST] = "ms_windup_thrust"
		},
		-- STATE_RECOVERY will not have anims for now, also can't set its anims to ANIM_NONE due to it still being used in pmodel lua anims
		[STATE_RECOVERY] = {nil},
		[STATE_ATTACK] = {
			[ANIM_NONE] = nil,
			[ANIM_STRIKE] = "ms_attack_strike",
			[ANIM_UPPERCUT] = "ms_attack_uppercut",
			[ANIM_UNDERCUT] = "ms_attack_undercut",
			[ANIM_THRUST] = "ms_attack_thrust"
		}
	}
	function AnimInit(p)
		p.m_aRHand = Angle() -- p:GetManipulateBoneAngles(p.m_iRHand)
		p.m_aRForearm = Angle() -- p:GetManipulateBoneAngles(p.m_iRForearm)
		p.m_aRUpperarm = Angle() -- p:GetManipulateBoneAngles(p.m_iRUpperarm)
		local w = p:GetActiveWeapon()
		local cycle = (w.m_bRiposting and w.m_iState == STATE_WINDUP) and 1 - w.RiposteMulti or 0 -- No clues on how to setplaybackrate for gestures.
		if defseq[w.m_iState][w.m_iAnim] ~= nil then
			p:AddVCDSequenceToGestureSlot(math.random(0, 6), p:LookupSequence(defseq[w.m_iState][w.m_iAnim]), cycle, true)
		end
		if w.m_iFlip ~= 1 then
			p:EnableMatrix ("RenderMultiply", Matrix({{1, 0, 0, 0},{0, -1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 1}}))
		else
			p:DisableMatrix("RenderMultiply")
		end
	end
end
do
	
end

	function EmoteInit(p)

	end
do
	local camt = {
		origin = nil,
		angles = nil,
		fov = 120,
		drawviewer = false
	}
	-- Must be in order
	local tglfieldt = {
		{
			"gmod_undo",
			"+menu_context"
		},
		{
			true, -- LocalPlayer()
			true -- camt 
		},
		{
			"m_bEmotePanelActive",
			"drawviewer"
		}
	}
	-- This hook triggers anytime a bind is pressed (no hold), just FYI
	function GM:PlayerBindPress(p, bind)

		-- Reset the fields, apparently doesn't set them in time :( Should put this into different hook maybe
		tglfieldt[2][1] = LocalPlayer()
		tglfieldt[2][2] = camt

		-- Binds that get sent to server
		for k, v in pairs(ATTACK_BIND) do -- Not sequential
			if string.find(bind, v) then
				net.Start("ms_bind_attack")
					net.WriteUInt(k, 3)
					net.WriteBool(p:GetActiveWeapon().m_bFlip)
				net.SendToServer()
			end
		end
		for k, v in ipairs(OTHER_BIND) do
			if bind == v then -- string.find(bind,v) then -- This messes with +menu and +menu_context
				net.Start("ms_bind_other")
					net.WriteUInt(k, 3)
				net.SendToServer()
			end
		end
		-- Binds that toggle fields in client
		for k, v in ipairs(tglfieldt[1]) do
			if bind == v then
				tglfieldt[2][k][tglfieldt[3][k]] = not tglfieldt[2][k][tglfieldt[3][k]]
			end
		end
		-- Emote panel, "slot0" will index further, base is 9
		if p.m_bEmotePanelActive then
			if bind == "slot0" then
				-- Check for the first field in base, if nil then return to 0
				p.m_iEmotePanelIndices = DEF_EMOTE[p.m_iEmotePanelIndices * 9 + 10] ~= nil and p.m_iEmotePanelIndices + 1 or 0
			end
			for i = 1, 9 do
				if bind == ("slot" .. i) then
					local idx = p.m_iEmotePanelIndices * 9 + i
					if DEF_EMOTE[idx] ~= nil then
						net.Start("ms_emote")
							net.WriteUInt(idx ,8)
						net.SendToServer()
					else
						print(idx, "doesn't exist!")
					end
					p.m_iEmotePanelIndices = 0
					p.m_bEmotePanelActive = false
					break
				end
			end
		end
	end

	hook.Add("CalcView", "SwitchPerspective", function(_p, _v, a)
		if LocalPlayer().CSENT then
			if camt.drawviewer then
				camt.origin = LocalPlayer():GetPos() + LocalPlayer():EyeAngles():Forward()*-32 + Vector(0, 0, 64)
				--camt.origin = LocalPlayer():GetPos() + LocalPlayer():EyeAngles():Forward()*64 + Vector(0, 0, 64)
				--camt.angles = a:__sub(Angle(180, 0, 180))
				LocalPlayer().CSENT:SetColor(Color(255, 255, 255, 0))
			else
				camt.origin = nil
				camt.angles = nil
				LocalPlayer().CSENT:SetColor(Color(255, 255, 255, 255))
			end
			return camt
		end
	end)
end

concommand.Add("ms_help", function() 
	print
	[[
	Welcome to Melee Slasher.
	If you've played Chivalry or MORDHAU before you should feel at home,  
	as the gamemode mechanics makes akin to it: riposting, feinting and 
	swing manipulation.                                                 
	If you are new to this game genre then proceed to read below.      

	It is crucial to use the core mechanic of this game - riposting.
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

function GM:PlayerTick(p, mv) -- Provides CMoveData context, works only on maxplayers > 1
	p:GetActiveWeapon().m_bFlip = mv:KeyDown(IN_RELOAD)
end

local function CL_TRACER_DRAW(...) -- Bad hook
	local vargt = {...}
	for _, v in ipairs(vargt) do
		table.insert(CL_LINE_DATA, v)
	end
	timer.Simple(CL_TRACER_LIFETIME:GetFloat(), function()
		for i = 1, #vargt do
			table.remove(CL_LINE_DATA, 1)
		end
	end)
end

-- Sets target for vgui stuff
hook.Add("CalcViewModelView","ms_SetTarget", function() 
	local p = LocalPlayer()
	p.m_eTarget = (IsValid(p:GetEyeTrace().Entity) and p:GetEyeTrace().Entity:GetClass() == "player") and p:GetEyeTrace().Entity or nil
end)


do
	local recovery_flAng, fpos, fang
	hook.Add("CalcViewModelView","ms_VModelLuaAnim", function() 
		if LocalPlayer() and not LocalPlayer().CSENT and LocalPlayer():GetActiveWeapon().Model then -- Init CSENT, we could use GM:InitPostEntity() instead though
			local p = LocalPlayer()
			p.CSENT = ClientsideModel(p:GetActiveWeapon().Model, RENDERGROUP_BOTH)
			p.CSENT:SetRenderMode(RENDERMODE_TRANSCOLOR)
			
			p.m_iEmotePanelIndices = 0
			p.m_bEmotePanelActive = false
			p.m_iStamina = 100
			p.m_iMaxStamina = 100
			p.m_eTarget = nil
		end

		if IsValid(LocalPlayer():GetActiveWeapon()) and LocalPlayer().CSENT then -- 1P
			local p = LocalPlayer()
			local w = p:GetActiveWeapon()
			local ea = p:EyeAngles()
			local ep = p:EyePos()
			local flip = w.m_iFlip
			local P_CSENT = LocalPlayer().CSENT

			-- Deprecated mess
			if w.m_iState == STATE_IDLE then
				fpos = ep+ea:Forward()*16+ea:Right()*8
				fang = Angle(ea[1]+90, ea[2], 0)
			elseif w.m_iState == STATE_PARRY then
				fpos = ep+ea:Forward()*16
				fang = Angle(ea[1], ea[2]-90, 0)
			elseif w.m_iState == STATE_WINDUP then
				local multi = w.m_bRiposting and w.RiposteMulti or 1
				local flAng = (CurTime()-w.m_flPrevState)/(w.Windup*multi)
				if w.m_iAnim == ANIM_STRIKE then
					fpos = ep+ea:Forward()*(8-16*flAng)+ea:Right()*8*flip+ea:Up()*-8
					fang = Angle(ea[1], ea[2]+15*flip, 90)
				elseif w.m_iAnim == ANIM_UPPERCUT then
					fpos = ep+ea:Forward()*16+ea:Right()*(8*flip+16*flAng*flip)+ea:Up()*(16*flAng)
					fang = Angle(ea[1]+45, ea[2], 0)
				elseif w.m_iAnim == ANIM_UNDERCUT then
					fpos = ep+ea:Forward()*(8-16*flAng)+ea:Right()*8*flip+ea:Up()*(-8-16*flAng)
					fang = Angle(ea[1]-45, ea[2], 90)
				elseif w.m_iAnim == ANIM_THRUST then
					fpos = ep+ea:Forward()*(16-8*flAng)+ea:Up()*-8+ea:Right()*8*flip
					fang = Angle(ea[1]-180, ea[2], 0)
				end
			elseif w.m_iState == STATE_RECOVERY then
				local flAng = 16*(CurTime()-w.m_flPrevState) / w.Recovery
				local recovery_st, recovery_en
				if w.m_iAnim ~= ANIM_THRUST and w.m_iAnim ~= ANIM_NONE then -- Slash attacks
					local inv, rot = unpack(CALC_SLASH[w.m_iAnim]) -- Might be expensive?
					local normal = Angle(w.AngleStrikeOffset*inv - ea[1] + recovery_flAng*inv, 180+ea[2], 0)
					normal:RotateAroundAxis(ea:Forward(), rot*flip)
					recovery_st = ep + normal:Forward() * (32 - flAng) + normal:Right() * 8*inv*flip
					recovery_en = ep + normal:Forward() * (32 + w.Range) + normal:Right() * 8*inv*flip
					fpos = recovery_st
					fang = (recovery_st - recovery_en):Angle()
				elseif w.m_iAnim == ANIM_THRUST then
					local normal = Angle(Angle(ea[1] + math.cos(math.rad(270*recovery_flAng/90)) * 2, ea[2] - math.sin(math.rad(270*recovery_flAng/90)) * 2*flip, 0))
					recovery_st = ep + normal:Forward() * ((32+6*(recovery_flAng/90))-flAng) + normal:Up() * -8 + normal:Right() * 8*flip
					recovery_en = ep + normal:Forward() * ((32 + w.Range)+6*(recovery_flAng/90)) + normal:Up() * -8 + normal:Right() *8*flip
					fpos = recovery_st
					fang = (recovery_st - recovery_en):Angle()
				elseif w.m_iAnim == ANIM_NONE then
					fpos = ep+ea:Forward()*16+ea:Right()*8
					fang = Angle(ea[1]+90, ea[2], 0)
				end
			elseif w.m_iState == STATE_ATTACK then
				local flAng = (CurTime()-w.m_flPrevState) / w.Release
				local st, en
				if w.m_iAnim ~= ANIM_THRUST then
					local inv, rot = unpack(CALC_SLASH[w.m_iAnim]) -- Might be expensive?
					local normal = Angle(w.AngleStrikeOffset*inv - ea[1] + flAng*inv, 180+ea[2], 0)
					normal:RotateAroundAxis(ea:Forward(), rot*flip)
					st = ep + normal:Forward() * 32 + normal:Right() * 8*inv*flip
					en = ep + normal:Forward() * (32 + w.Range) + normal:Right() * 8*inv*flip
				else
					local normal = Angle(Angle(ea[1] + math.sin(math.rad(270/(90/flAng)+90)) * 2, ea[2] - math.sin(math.rad(270/(90/flAng))) * 2*flip, 0))
					st = ep + normal:Forward() * (32+12*(1/(90/flAng))) + normal:Up() * -8 + normal:Right() * 8 * flip
					en = ep + normal:Forward() * ((32 + w.Range)+12*(1/(90/flAng))) + normal:Up() * -8 + normal:Right() * 8 * flip
				end
				if CL_DRAW_TRACERS:GetBool() then
					CL_TRACER_DRAW(st, en)
				end
				recovery_flAng = flAng -- Both
				fpos = st
				fang = (st - en):Angle()
			end
			if ENABLE_CSENT:GetBool() then -- Should also affect everything but state_attack, this is temporary
				P_CSENT:SetPos(fpos)
				P_CSENT:SetAngles(fang)
			end
		end
	end)
end

do
	hook.Add("PostPlayerDraw", "ms_PmodelLuaAnim", function(p) 
		if IsValid(p:GetActiveWeapon()) then
			-- Can be faulty if playermodel is changed
			if not p.m_iRHand then
				p.m_flPrevAng = 0.0
				p.m_iRUpperarm = p:LookupBone("ValveBiped.Bip01_R_UpperArm")
				p.m_iRForearm = p:LookupBone("ValveBiped.Bip01_R_Forearm")
				p.m_iRHand = p:LookupBone("ValveBiped.Bip01_R_Hand")
			end

			local w = p:GetActiveWeapon()
			local ea = p:EyeAngles()

			--DT testing
			--w.m_iState = w:GetDTInt(WEP_STATE)
			--w.m_iAnim = w:GetDTInt(WEP_ANIM)
			--w.m_bRiposting = w:GetDTBool(0)

			-- Inverts poseparams and texture normals because pmodel gets enablematrix'd with a negative value
			p.RenderOverride = function(self)
				if w.m_iFlip ~= 1 then
					render.CullMode(MATERIAL_CULLMODE_CW)
					for _, v in ipairs({"aim_yaw", "move_y"}) do
						local min, max = self:GetPoseParameterRange(self:LookupPoseParameter(v))
						self:SetPoseParameter(v, min+max - math.Remap(self:GetPoseParameter(v), 0, 1, min, max))
					end
					self:DrawModel()
					render.CullMode(MATERIAL_CULLMODE_CCW)
				else
					self:DrawModel()
				end
			end

			-- Soon to be deprecated too
			--[[
			if w.m_iState == STATE_IDLE then
				if not p:GetManipulateBoneAngles(p.m_iRHand):__eq(Angle()) then -- rhand is always changed
					local flFraction = 1 - math.ease.OutCubic(math.Clamp((CurTime()-w.m_flPrevState)/w.Recovery, 0, 1))
					p:ManipulateBoneAngles(p.m_iRHand, p.m_aRHand:__mul(flFraction))
					p:ManipulateBoneAngles(p.m_iRForearm, p.m_aRForearm:__mul(flFraction))
					p:ManipulateBoneAngles(p.m_iRUpperarm, p.m_aRUpperarm:__mul(flFraction))
				end
			elseif w.m_iState == STATE_PARRY then -- Do nothing, we change aimlayer instead
			elseif w.m_iState == STATE_WINDUP then -- Only attack anims can be here
					local multi = w.m_bRiposting and w.RiposteMulti or 1
					local flAng = math.Clamp(90/((w.Windup*multi)/(CurTime()-w.m_flPrevState)), 0, 90)
				if w.m_iAnim == ANIM_STRIKE then
					p:ManipulateBoneAngles(p.m_iRHand, Angle(-flAng, 0, 0))
					p:ManipulateBoneAngles(p.m_iRForearm, Angle(0, flAng, 0))
					p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(0, flAng, 0))
				elseif w.m_iAnim == ANIM_UPPERCUT then
					p:ManipulateBoneAngles(p.m_iRHand, Angle(0, -flAng, flAng))
					p:ManipulateBoneAngles(p.m_iRForearm, Angle(0, flAng, 0))
					p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(flAng, 0, 0))
				elseif w.m_iAnim == ANIM_UNDERCUT then
					p:ManipulateBoneAngles(p.m_iRHand, Angle(0, -flAng, flAng))
					p:ManipulateBoneAngles(p.m_iRForearm, Angle(0, flAng, 0))
				elseif w.m_iAnim == ANIM_THRUST then
					p:ManipulateBoneAngles(p.m_iRHand, Angle(0, 0, -flAng/2))
					p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(0, flAng, 0))
				end
			elseif w.m_iState == STATE_RECOVERY then
				local flFraction = 1 - math.ease.InCubic(math.Clamp((CurTime()-w.m_flPrevState)/w.Recovery, 0, 1))
				p:ManipulateBoneAngles(p.m_iRHand, p.m_aRHand:__mul(flFraction))
				p:ManipulateBoneAngles(p.m_iRForearm, p.m_aRForearm:__mul(flFraction))
				p:ManipulateBoneAngles(p.m_iRUpperarm, p.m_aRUpperarm:__mul(flFraction))
			elseif w.m_iState == STATE_ATTACK then
				local flAng = 0.0
				if w.m_iAnim == ANIM_STRIKE then -- Only attack anims can be here
					flAng = math.Clamp((CurTime()-w.m_flPrevState)/w.Release, 0, w.AngleStrike)
					p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(60*math.sin(math.rad(flAng*(4/3))), 90-flAng*(4/3)+30), flAng*0.4)
				elseif w.m_iAnim == ANIM_UPPERCUT then
					flAng = math.Clamp((CurTime()-w.m_flPrevState)/w.Release, 0, w.AngleStrike)
					p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(90+flAng, 90-30*flAng/w.AngleStrike, 120))
				elseif w.m_iAnim == ANIM_UNDERCUT then
					flAng = math.Clamp((CurTime()-w.m_flPrevState)/w.Release, 0, w.AngleStrike)
					p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(-30*flAng/w.AngleStrike, -flAng, 0))
				elseif w.m_iAnim == ANIM_THRUST then
					flAng = CurTime()-w.m_flPrevState
					local pace_90 = math.Clamp(flAng/w.Release, 0, 90) -- a thrust will always have only 90 iterations(?)
					p:ManipulateBoneAngles(p.m_iRHand,Angle(-100*pace_90/90, -15*pace_90/90, -90+pace_90))
					p:ManipulateBoneAngles(p.m_iRForearm,Angle(0, pace_90, 0))
					p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(0, 90-180*pace_90/90, 0))
				end
				p.m_flPrevAng = flAng
			end
			]]
		end
	end)
end

function GM:BuildUserInterface()
	self.ProgressBars = vgui.Create("ProgressBars")
	self.EmotePanel = vgui.Create("EmotePanel")
	self.DamageIndicator = vgui.Create("DamageIndicator")
end

function GM:Initialize()
	self:BuildUserInterface()
end

do
	local ctable = {
		[1] = Color(255, 0, 0),
		[2] = Color(0, 255, 255),
		[3] = Color(0, 255, 0)
	}
	hook.Add("PostDrawOpaqueRenderables", "ms_DBG_TraceDraw", function()
		for i = 1, #SV_LINE_DATA, 4 do
			render.DrawLine(SV_LINE_DATA[i], SV_LINE_DATA[i+1], ctable[SV_LINE_DATA[i+2]])
			if SV_LINE_DATA[i+4] and SV_LINE_DATA[i+7] == SV_LINE_DATA[i+3] then
				render.DrawLine(SV_LINE_DATA[i+1], SV_LINE_DATA[i+5], Color(0, 255, 0))
			end
		end
		for i = 1, #CL_LINE_DATA, 2 do
			render.DrawLine(CL_LINE_DATA[i], CL_LINE_DATA[i+1], Color(255, 255, 0))
		end
	end)
end

do
	local forbidden_huds = {
		["CHudHealth"] = true,
		["CHudBattery"] = true,
		["CHudAmmo"] = true,
		["CHudSecondaryAmmo"] = true,
		["CHudWeaponSelection"] = true,
		["CHudGMod"] = true -- Disables hudpaint hook
	}
	hook.Add("HUDShouldDraw", "ms_HideHUD", function(name)
		return forbidden_huds[name] and false
	end)
end

hook.Add("CreateMove", "ms_Turncap", function(cmd)
	local w = LocalPlayer():GetActiveWeapon()
	local viewangles = cmd:GetViewAngles()
	
	if IsValid(w) and w.viewangles and w.m_iState ~= STATE_RECOVERY and w.m_iState ~= STATE_IDLE then
		do
			local maxdiff = FrameTime() * w.TurnCap
			local mindiff = -maxdiff
			local originalangles = w.viewangles
			local diffyaw = math.AngleDifference(viewangles[2], originalangles[2])
			local diffpitch = math.AngleDifference(viewangles[1], originalangles[1])
			
			viewangles[2] = math.NormalizeAngle(originalangles[2] + math.Clamp(diffyaw, mindiff, maxdiff))
			viewangles[1] = math.NormalizeAngle(originalangles[1] + math.Clamp(diffpitch, mindiff, maxdiff))
		end
		w.viewangles = viewangles
	end
	cmd:SetViewAngles(Angle(math.Clamp(viewangles[1], -60, 60), viewangles[2], viewangles[3]))
end)