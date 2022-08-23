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

	-- For some reason anything but lp doesn't get set to ANIM_NONE when STATE_PARRY? this is a hotfix.
	if self.m_iState == STATE_PARRY then
		self.m_iAnim = ANIM_NONE
	end

	if o ~= LocalPlayer() then
		if self.m_iState and self.m_iAnim then -- ?
			local seq = DEF_ANM_SEQUENCES[self.m_iState][self.m_iAnim]
			if seq ~= nil then
				if seq == "ms_parry" then -- Must be seperate boolean logic (hotfix)
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
end

-- Anything else below is for localplayer, stuff that happens without sv permission

function SWEP:Queue(a_state, flip)
	self.m_iQueuedAnim = a_state
	self.m_bQueuedFlip = flip
	if ((self.m_iState == STATE_IDLE --[[and self.m_flPrevState + self.Recovery <= CurTime()]]) or self.m_iState == STATE_PARRY) and not self.m_bRiposting then
		net.Start("ms_anim_queue")
			net.WriteUInt(a_state, 3)
			net.WriteBool(flip)
		net.SendToServer()
	end

	if self.m_iState == STATE_IDLE and self.m_flPrevState + self.Recovery <= CurTime() then
		local p = LocalPlayer()
		self:StateUpdate(p, STATE_WINDUP, a_state, self.m_bRiposting, flip)
		self.viewangles = p:EyeAngles()
	end
end

function SWEP:StateUpdate(p, s, a, r, f)
	local w = p:GetActiveWeapon()
	if IsValid(w) then
		self.viewangles = LocalPlayer():EyeAngles() -- Turncap update
		local seq = DEF_ANM_SEQUENCES[s][a]
		if seq ~= nil then
			if seq == "ms_parry" then
				p:AddVCDSequenceToGestureSlot(1, p:LookupSequence(seq), 0, true)
			end
		else
			p:AnimResetGestureSlot(0)
		end

		w.m_iState = s or w.m_iState
		w.m_iAnim = a or w.m_iAnim
		w.m_bFlip = (f) or w.m_bFlip -- Sometimes changes to nil? Mandatory fallback
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
	local p = LocalPlayer()
	if CurTime() >= self.m_flPrevParry and (self.m_iState == STATE_IDLE or 
	(self.m_iState == STATE_WINDUP --[[and CurTime() <= self.m_flPrevState + self.Windup ]]))
	then

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