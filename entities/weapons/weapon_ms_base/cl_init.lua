INC_CLIENT()

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Int", 1, "Anim")
	self:NetworkVar("Bool", 0, "Riposte")
	self:NetworkVar("Bool", 1, "Flip")

	self:NetworkVar("Bool", 2, "Success") -- For cl anim

	self:NetworkVarNotify("State", function(ent, name, old, new)
		self.m_iState = new
		self.m_flPrevState = CurTime()
		--self.m_flPrevFeint
		self:AnimInit()
	end)
	self:NetworkVarNotify("Anim", function(ent, name, old, new)
		self.m_iAnim = new
		self.m_iQueuedAnim = self:GetOwner() == LocalPlayer() and new
	end)
	self:NetworkVarNotify("Riposte", function(ent, name, old, new)
		self.m_bRiposting = new
	end)
	self:NetworkVarNotify("Flip", function(ent, name, old, new)
		self.m_bFlip = new
		self.m_iFlip = new and 1 or -1
	end)
	self:NetworkVarNotify("Success", function(ent, name, old, new)
		self.m_flPrevParry = 0.0
	end)
end

-- This is still a callback for both lplayer and pl
function SWEP:AnimInit()
	local o = self:GetOwner()
	o:AnimResetGestureSlot(GESTURE_SLOT_VCD) -- Emotes
	if o == LocalPlayer() then
		self.viewangles = LocalPlayer():EyeAngles()
	end 
	if self.m_iState == STATE_PARRY then
		self.m_iAnim = ANIM_NONE -- wip temp
	end
	if o ~= LocalPlayer() then
		local seq = DEF_ANM_SEQUENCES[self.m_iState][self.m_iAnim]
		if seq ~= nil then
			if seq ~= "CONTINUE" then
				o:AddVCDSequenceToGestureSlot(seq ~= "ms_parry" and 0 or 1, o:LookupSequence(seq), 0, true)
			end
		else
			o:AnimResetGestureSlot(0)
		end
	end

	-- For UpdateAnimation
	for k in ipairs(self.m_tCurTimeBank) do
		if self.m_iState == k then
			self.m_tCurTimeBank[k] = self.m_flPrevState
			--print(DBG_STATE[k], "P", self.m_flPrevState)
			break
		end
	end
	if self.m_iState == STATE_RECOVERY then
		-- Uncommenting this will cause artifacts
		if (self.m_tCurTimeBank[STATE_RECOVERY] - self.m_tCurTimeBank[STATE_ATTACK]) > 1 then -- Bandaid fix, if state_attack doesn't update
			self.m_flCycle = 0
		else
			self.m_flCycle = (self.m_tCurTimeBank[STATE_RECOVERY] - self.m_tCurTimeBank[STATE_ATTACK] ) / (self.Release * self.AngleStrike)
		end
		self.m_flWeightRecovery = 1
	end
	if o ~= LocalPlayer() then
		if self.m_iState == STATE_WINDUP or self.m_iState == STATE_IDLE or self.m_iState == STATE_PARRY then
			print(self.m_iState)
			--self.m_flCycle = 0
			--self.m_flWeight = 0
		end
	end
end

-- Anything else below is for localplayer
-- Seperated for setting lplayer's animations without server's permission
function SWEP:AnimInitLocalPlayer(s, a)
	local p = LocalPlayer()
	local w = p:GetActiveWeapon()
	self.m_iState = s -- For UpdateAnimation
	self.m_iAnim = a
	self.viewangles = LocalPlayer():EyeAngles() -- For Turncap
	local seq = DEF_ANM_SEQUENCES[s][a]
	if seq ~= nil then
		if seq ~= "CONTINUE" then
			p:AddVCDSequenceToGestureSlot(seq ~= "ms_parry" and 0 or 1, p:LookupSequence(seq), 0, true)
		end
	else
		p:AnimResetGestureSlot(0)
	end

	if s == STATE_WINDUP or s == STATE_PARRY or s == STATE_IDLE then
		--self.m_flCycle = 0
		--self.m_flWeight = 0 -- !!! This sometimes gets skipped!
	end
end

function SWEP:Queue(a_state, flip)
	self.m_iQueuedAnim = a_state
	self.m_bQueuedFlip = flip

	-- Updates queued anim
	if (self.m_iState == STATE_IDLE or self.m_iState == STATE_PARRY) and not self.m_bRiposting then
		net.Start("ms_anim_queue")
			net.WriteUInt(a_state, 3)
			net.WriteBool(flip)
		net.SendToServer()
	end

	if self.m_iState == STATE_IDLE and self.m_flPrevState + self.Windup <= CurTime() then
		local p = LocalPlayer()
		local iFlipFinal = flip and -1 or 1
		self:StateUpdate(p, STATE_WINDUP, a_state, self.m_bRiposting, flip)
		self.viewangles = p:EyeAngles()
	end
end

function SWEP:StateUpdate(p, s, a, r, f)
	local w = p:GetActiveWeapon()
	if IsValid(w) then
		w.m_iState = s or w.m_iState
		w.m_iAnim = a or w.m_iAnim

		self:AnimInitLocalPlayer(s, a)
	end
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	self:Queue(ANIM_STRIKE, self.m_bFlip)
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end
	self:Parry()
end

function SWEP:Parry()
	if CurTime() >= self.m_flPrevParry and self.m_iState <= STATE_RECOVERY then
		local p = LocalPlayer()

		-- Reset fields
		self.m_bRiposting = false
		self.m_bQueuedFlip = false
		self.m_iQueuedAnim = ANIM_NONE
		
		self.m_flPrevParry = CurTime() + 1 + 1/3
		
		if self.m_iState == STATE_IDLE or STATE_WINDUP then
			self:StateUpdate(p, STATE_PARRY, ANIM_NONE)
		end
	end
end

--[[
function SWEP:CalcViewModelView(vm, oP, oA)
	return oP, oA
end

function SWEP:AnimInitLocalPlayer(s, a)
	--if s == STATE_ATTACK then return end
	local p = LocalPlayer()
	local w = p:GetActiveWeapon()
	self.m_iState = s -- For UpdateAnimation
	self.m_iAnim = a
	self.viewangles = LocalPlayer():EyeAngles() -- For Turncap
	local seq = DEF_ANM_SEQUENCES[s][a]
	if seq ~= nil then
		if seq ~= "CONTINUE" then
			p:AddVCDSequenceToGestureSlot(0, p:LookupSequence(seq), 0, true)
		end
	else
		p:AnimResetGestureSlot(0)
	end
	-- For UpdateAnimation, only refreshes parry and windup in this method
	for k in ipairs(self.m_tCurTimeBank) do
		if s == k then
			self.m_tCurTimeBank[k] = CurTime()
			print(DBG_STATE[k], "LP")
			break
		end
	end
	if s == STATE_WINDUP or s == STATE_PARRY then
		--timer.Simple(0, function() -- good ol timer, sugma balls
			self.m_flCycle = 0
			self.m_flWeight = 0 -- !!! This sometimes gets skipped if it's not called on next frame!
			--print(self.m_flCycle, self.m_flWeight, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
		--end)
	end
end
]]
--[[
-- Called from server, both applicable for lp and ply for now?
function SWEP:AnimInit()
	local o = self:GetOwner()
	if o == LocalPlayer() then
		-- If attack or recovery on localplayer, then proceed (not predicted for now)
		self.viewangles = LocalPlayer():EyeAngles()
		if self.m_iState ~= STATE_RECOVERY and self.m_iState ~= STATE_ATTACK then
			--print(DBG_STATE[self.m_iState], "fallback")
		return
		else
			--self.viewangles = LocalPlayer():EyeAngles() -- For Turncap
		end
	end 
	if self.m_iState == STATE_PARRY then
		self.m_iAnim = ANIM_NONE -- wip temp
	end
	if o ~= LocalPlayer() then
		local seq = DEF_ANM_SEQUENCES[self.m_iState][self.m_iAnim]
		if seq ~= nil then
			if seq ~= "CONTINUE" then
				o:AddVCDSequenceToGestureSlot(0, o:LookupSequence(seq), 0, true)
			end
		else
			o:AnimResetGestureSlot(0)
		end
	end

	-- For UpdateAnimation
	for k in ipairs(self.m_tCurTimeBank) do
		if self.m_iState == k then
			self.m_tCurTimeBank[k] = self.m_flPrevState
			print(DBG_STATE[k], "P")
			break
		end
	end
	if self.m_iState == STATE_RECOVERY then
		-- This shit causes so many issues
		-- self.m_flCycle = math.Clamp((self.m_tCurTimeBank[STATE_RECOVERY] - self.m_tCurTimeBank[STATE_ATTACK] ) / (self.Release * self.AngleStrike), 0, 1)
		-- self.m_flWeight = 0
	elseif o ~= LocalPlayer() then -- It's called on localplayer method already
		if self.m_iState == STATE_WINDUP then
			self.m_flCycle = 0
			self.m_flWeight = 0
		end
	end
end
]]

-- This no longer gets ever called due to timers being stripped away from it
--[[
function SWEP:Attack(riposte, flip)
	local o = self:GetOwner()
	self.m_tFilter[#self.m_tFilter + 1] = o
	
	self.m_bFlip = flip == -1
	self:StateUpdate(o, STATE_ATTACK, self.m_iAnim, riposte, self.m_bFlip) -- ANIM_SKIP
	self.m_flPrevRecovery = CurTime() + self.Recovery + self.AngleStrike * self.Release
	self.slashtag = self:EntIndex()
	local attachid
	for i = 0, o:GetBoneCount() - 1 do
		attachid = o:GetBoneName(i)
		if attachid == "ValveBiped.Anim_Attachment_RH" then
			attachid = i
			break
		end
	end
	if not attachid then
		print("ValveBiped.Anim_Attachment_RH wasn't found!")
	end
	
	local iAngleFinal = self.m_iAnim ~= ANIM_THRUST and self.AngleStrike - 4 or 90
	local incrmul = math.floor(engine.TickInterval() / self.Release + 0.5)
	local st, en, bm, v, a

	local iThink = 0
	local iAng = 0
	local nxt = 0
	function self:Think()
		if CurTime() >= nxt then
		if self.m_iState == STATE_ATTACK then
			for iAng = 1, incrmul do
				bm = o:GetBoneMatrix(attachid)
				v = bm:GetTranslation(attachid)
				a = bm:GetAngles()
				st = v + a:Right() * iAng -- Perhaps could use some sort of get for next cycle's position?
				en = st + a:Right() * -self.Range
				local tr = util.TraceLine({
					start = st,
					endpos = en,
					filter = self.m_tFilter
				})
				-- Draw DBG Tracers, affiliate it with glance angles
				if CL_DRAW_TRACERS:GetBool() and tr.Entity == NULL then
					local idx = 1
					if self.m_iAnim ~= ANIM_THRUST then
						idx = iAng > self.GlanceAngles and 1 or 2
					end
					CL_TRACER_DRAW(st, en)
				end
				if iThink + iAng >= iAngleFinal then
					self:AttackFinish()
					break
				end
			end
			iThink = iThink + incrmul
		end
		nxt = CurTime() + FrameTime()
		end
	end
end

function SWEP:AttackFinish(tracerst, traceren, tracertag)
	local o = self:GetOwner()
	
	self.m_flPrevRecovery = CurTime() + self.Recovery
	
	self:StateUpdate(o, STATE_RECOVERY, self.m_iAnim, false, self.m_bFlip)

	table.Empty(self.m_tFilter)
	self.m_bRiposting = false
	if tracerst then
		local effectdata = EffectData()
		effectdata:SetOrigin(traceren)
		util.Effect("MetalSpark", effectdata, true, false)

		if CL_DRAW_TRACERS:GetBool() then
			CL_TRACER_DRAW(tracerst, traceren)
		end
	end
end

function SWEP:Riposte(p)
	p:ViewPunch(Angle(-2, 0, 0))

	local w = p:GetActiveWeapon()
	w.m_flPrevRecovery = 0.0
	w.m_flPrevParry = 0.0
	w.m_flPrevFlinch = 0.0
end

function SWEP:Feint()
	if self.m_iState == STATE_WINDUP and not self.m_bRiposting and self:GetOwner().m_iStamina ~= 0 then
		local o = self:GetOwner()
		self.m_iQueuedAnim = ANIM_NONE
		self:StateUpdate(o, STATE_IDLE)
	end
end
]]
