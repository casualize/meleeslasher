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

CL_FOV = CreateConVar("ms_cl_fov", "120", true, false)
CL_DRAW_TRACERS = CreateConVar("ms_cl_draw_tracers", "0", true, false)
CL_TRACER_LIFETIME = CreateConVar("ms_cl_cl_tracers_lifetime", "1", true, false)
SV_TRACER_LIFETIME = CreateConVar("ms_cl_sv_tracers_lifetime", "1", true, false)

local CL_LINE_DATA = {}
local SV_LINE_DATA = {}

-- Rewrite this
net.Receive("ms_tracer_server", function()

	SV_LINE_DATA[#SV_LINE_DATA + 1] = net.ReadVector() -- st
	SV_LINE_DATA[#SV_LINE_DATA + 1] = net.ReadVector() -- en
	SV_LINE_DATA[#SV_LINE_DATA + 1] = net.ReadUInt(2) -- col
	SV_LINE_DATA[#SV_LINE_DATA + 1] = net.ReadUInt(16) -- tag

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
	local w = Player(p):GetActiveWeapon()
	if w then
		w.m_flPrevState = CurTime()
		w.m_iState		= net.ReadUInt(3)
		w.m_iAnim		= net.ReadUInt(3)
		w.m_bRiposting	= net.ReadBool()
		w.m_iFlip		= net.ReadBool() and -1 or 1 -- Converts from bool to number for arithmetic purpose
		AnimInit(Player(p))
	end
end)

net.Receive("ms_player_inflict", function()
	local p = net.ReadUInt(16) -- UserID
	Player(p):AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_PHYSICS, true)
end)

net.Receive("ms_emote", function()
	local p = net.ReadUInt(16) -- UserID
	local e = net.ReadUInt(8)
	Player(p):AddVCDSequenceToGestureSlot(0, Player(p):LookupSequence(DEF_EMOTE[e]), 0, true)
end)

DMG_DATA = {}
net.Receive("ms_damageindicator", function()
	local dmgtable = {
		[1] = net.ReadUInt(16), -- UserID
		[2] = net.ReadUInt(16), -- Damage
		[3] = CurTime() + 6 -- Fade time
	}
	-- This still plays the hit sound on very low pings
	surface.PlaySound("meleeslasher/" .. ((Player(dmgtable[1]):Health() --[[- dmgtable[2]]) > 1 and "hitsound.wav" or "killsound.ogg"))
	-- Fetch old damage amount, increment
	for k, v in ipairs(DMG_DATA) do
		if dmgtable[1] == v[1] then
			dmgtable[2] = dmgtable[2] + v[2]
			table.remove(DMG_DATA, k) -- Shift all other values down
			break
		end
	end
	table.insert(DMG_DATA, dmgtable) -- Push to top
end)

net.Receive("ms_ea_update", function()
	LocalPlayer():GetActiveWeapon().viewangles = LocalPlayer():EyeAngles()
end)

function GM:InitPostEntity()
	local p = LocalPlayer()

	p.m_flJumpStartTime = 0
	p.m_iEmotePanelIndices = 0
	p.m_bEmotePanelToggle = false
	p.m_bPerspectiveToggle = false
	p.m_iStamina = 100
	p.m_iMaxStamina = 100
	p.m_eTarget = nil 

	self:BuildUserInterface()

	-- Hooks that get called before LocalPlayer()
	hook.Add("CreateMove", "DuckJumpAlter", DuckJumpAlter)
end

function AnimInit(p)
	local w = p:GetActiveWeapon()
	if IsValid(w) then
		-- AddVCDSequenceToGestureSlot method is very limited
		local seq = DEF_ANM_SEQUENCES[w.m_iState][w.m_iAnim]
		if seq ~= nil then
			if seq ~= "CONTINUE" then
				p:AddVCDSequenceToGestureSlot(0, p:LookupSequence(seq), 0, true)
			end
		else
			p:AnimResetGestureSlot(0)
		end

		-- For UpdateAnimation
		for k in ipairs(w.m_tCurTimeBank) do
			if w.m_iState == k then
				w.m_tCurTimeBank[k] = w.m_flPrevState
				break
			end
		end
		if w.m_iState == STATE_RECOVERY then
			w.m_flCycle = math.Clamp((w.m_tCurTimeBank[STATE_RECOVERY] - w.m_tCurTimeBank[STATE_ATTACK] ) / (w.Release * w.AngleStrike), 0, 1)
			w.m_flWeight = 1
		elseif w.m_iState == STATE_WINDUP then
			w.m_flCycle = 0
			w.m_flWeight = 0
		elseif w.m_iState == STATE_IDLE then
			w.m_flWeight = w.m_tCurTimeBank[STATE_WINDUP] > w.m_tCurTimeBank[STATE_RECOVERY] and math.Clamp((w.m_tCurTimeBank[STATE_IDLE] - w.m_tCurTimeBank[STATE_WINDUP] ) / w.Windup, 0, 1) or 0
		end

		if w.m_iFlip ~= 1 then
			p:EnableMatrix ("RenderMultiply", Matrix({{1, 0, 0, 0},{0, -1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 1}}))
		else
			p:DisableMatrix("RenderMultiply")
		end
	end
end

do
	local camt = {
		origin = nil,
		angles = nil,
		fov = CL_FOV:GetInt(),
		drawviewer = true
	}
	-- Move this to global
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
			"m_bEmotePanelToggle",
			"m_bPerspectiveToggle" -- drawviewer
		}
	}
	-- This hook triggers anytime a bind is pressed (no hold), just FYI
	function GM:PlayerBindPress(p, bind)

		-- Reset the fields, apparently doesn't set them in time :( Should put this into different hook maybe
		tglfieldt[2][1] = LocalPlayer()
		tglfieldt[2][2] = LocalPlayer() -- camt

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
		if p.m_bEmotePanelToggle then
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
					end
					p.m_iEmotePanelIndices = 0
					p.m_bEmotePanelToggle = false
					break
				end
			end
		end
	end

	local attachment = {
		[1] = "ValveBiped.Bip01_Head1",
		[2] = "ValveBiped.Bip01_Neck1",
		[3] = "ValveBiped.Bip01_Spine4",
		[4] = "ValveBiped.Bip01_Spine2"
	}
	local attachid = {
		[1] = -1,
		[2] = -1,
		[3] = -1,
		[4] = -1
	}
	hook.Add("CalcView", "SwitchPerspective", function(_p, _v, _a)
		-- Put this on model change call
		for k, v in ipairs(attachment) do
			for i = 0, _p:GetBoneCount() - 1 do
				if v == _p:GetBoneName(i) then
					attachid[k] = i
					break
				end
			end
			v = -1
		end
		camt.fov = CL_FOV:GetInt()
		if _p.m_bPerspectiveToggle then
			for _, v in ipairs(attachid) do
				if v ~= -1 then
					_p:ManipulateBoneScale(v, Vector(1, 1, 1))
				end
			end
			camt.origin = _v + Angle(0, _a[2], 0):Forward()*-64
			camt.angles = Angle(0, _a[2], 0)
		else
			for _, v in ipairs(attachid) do
				if v ~= -1 then
					_p:ManipulateBoneScale(v, Vector())
				end
			end
			if attachid[1] ~= -1 then
				camt.origin = _p:GetBonePosition(attachid[1]) + Angle(0, _a[2], 0):Forward()*-2
				camt.angles = nil
			end
		end
		return camt
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
	
	FLIP ATTACK SIDE = +reload  (default: R, i recommend binding it to     
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

local function CL_TRACER_DRAW(...) -- Gets called multiple times if maxplayers > 1, bug
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

-- Sets target for progressbars vgui
hook.Add("CalcViewModelView","ms_SetTarget", function() 
	local p = LocalPlayer()
	p.m_eTarget = (IsValid(p:GetEyeTrace().Entity) and type(p:GetEyeTrace().Entity) == "Player") and p:GetEyeTrace().Entity or nil
end)

hook.Add("PostPlayerDraw", "ms_Playermodels", function(p) 
	if IsValid(p:GetActiveWeapon()) then

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
	end
end)

function GM:BuildUserInterface()
	self.ProgressBars = vgui.Create("ProgressBars")
	self.EmotePanel = vgui.Create("EmotePanel")
	self.DamageIndicator = vgui.Create("DamageIndicator")
end

function GM:Initialize()
	-- Override matproxy to colorize clientside models instead of default ragdolls
	local cfallback = Vector(1, 1, 1)
	local entity = FindMetaTable("Entity")
	local e_getclass = entity.GetClass
	local e_getowner = entity.GetOwner
	local p_getplayercolor = FindMetaTable("Player").GetPlayerColor
	matproxy.Add({
		name = "PlayerColor",
		init = function(self, mat, values)
			self.ref = values.resultvar
		end,
		bind = function(self, mat, ent)
			if not IsValid(ent) then return end
			if(ent.GetOwner and (e_getclass(ent) == "prop_corpse" or e_getclass(ent) == "class C_ClientRagdoll")) then
				-- It just works
				ent = e_getowner(ent)
			end
			mat:SetVector(self.ref, ent.GetPlayerColor and ent:GetPlayerColor() or cfallback)
		end
	})
end

do
	local ctable = {
		[1] = Color(255, 0, 0),
		[2] = Color(0, 255, 255),
		[3] = Color(0, 255, 0),
		[4] = Color(255, 255, 0)
	}
	hook.Add("PostDrawOpaqueRenderables", "ms_DBG_TraceDraw", function()
		for i = 1, #SV_LINE_DATA, 4 do
			render.DrawLine(SV_LINE_DATA[i], SV_LINE_DATA[i+1], ctable[SV_LINE_DATA[i+2]])
			if SV_LINE_DATA[i+4] and SV_LINE_DATA[i+7] == SV_LINE_DATA[i+3] then
				render.DrawLine(SV_LINE_DATA[i+1], SV_LINE_DATA[i+5], ctable[3])
			end
		end
		for i = 1, #CL_LINE_DATA, 2 do
			render.DrawLine(CL_LINE_DATA[i], CL_LINE_DATA[i+1], ctable[4])
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