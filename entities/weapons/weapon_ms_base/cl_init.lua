INC_CLIENT()

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Int", 1, "Anim")
	self:NetworkVar("Bool", 0, "Riposte")
	self:NetworkVar("Bool", 1, "Flip")

	self:NetworkVar("Bool", 2, "Success") -- For cl anim

	self:NetworkVarNotify("State", function(ent, name, old, new)
		self.m_iPrevState = old
		self.m_iState = new
		self.m_flPrevState = CurTime()
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
		self.m_bQueuedFlip = self:GetOwner() == LocalPlayer() and new
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
		if IsValid(self) then -- ?
			local seq = DEF_ANM_SEQUENCES[self.m_iState][self.m_iAnim]
			if seq ~= nil then
				if seq == "ms_parry" then
					o:AddVCDSequenceToGestureSlot(1, o:LookupSequence(seq), 0, true)
				end
			else
				o:AnimResetGestureSlot(0)
			end
			if self.m_iState == STATE_WINDUP then
				o:AnimRestartGesture(GESTURE_SLOT_JUMP, ACT_FLINCH_SHOULDER_RIGHT, true)
			end
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

	if self.m_iPrevState == STATE_ATTACK then
		if (self.m_tCurTimeBank[STATE_IDLE] - self.m_tCurTimeBank[STATE_ATTACK]) > 1 then -- Bandaid fix, if state_attack doesn't update
			self.m_flCycle = 0
		else
			self.m_flCycle = (self.m_tCurTimeBank[STATE_IDLE] - self.m_tCurTimeBank[STATE_ATTACK] ) / (self.Release * self.AngleStrike)
		end
		self.m_flWeightRecovery = 1
	end
	if o ~= LocalPlayer() then
		if self.m_iState == STATE_WINDUP or self.m_iState == STATE_IDLE or self.m_iState == STATE_PARRY then
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
		if seq == "ms_parry" then
			p:AddVCDSequenceToGestureSlot(1, p:LookupSequence(seq), 0, true)
		end
	else
		p:AnimResetGestureSlot(0)
	end

	if s == STATE_WINDUP or s == STATE_PARRY or s == STATE_IDLE then
		self.m_flCycle = 0
		self.m_flWeight = 0 -- !!! This sometimes gets skipped!
	end
end

function SWEP:Queue(a_state, flip)
	self.m_iQueuedAnim = a_state
	self.m_bQueuedFlip = flip

	-- Updates queued anim
	if ((self.m_iState == STATE_IDLE --[[and self.m_flPrevState + self.Recovery <= CurTime()]]) or self.m_iState == STATE_PARRY) and not self.m_bRiposting then
		net.Start("ms_anim_queue")
			net.WriteUInt(a_state, 3)
			net.WriteBool(flip)
		net.SendToServer()
	end

	if self.m_iState == STATE_IDLE and self.m_flPrevState + self.Recovery <= CurTime() then
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
	self:Queue(ANIM_STRIKE, self.m_bMVDATA)
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end
	self:Parry()
end

function SWEP:Parry()
	if CurTime() >= self.m_flPrevParry and (self.m_iState == STATE_IDLE or self.m_iState == STATE_WINDUP) then
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