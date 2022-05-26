INC_CLIENT()

--[[
function SWEP:CalcViewModelView(vm)
	if self.m_iState == STATE_IDLE then
		vm:SendViewModelMatchingSequence(vm:LookupSequence("idle_01"))
	elseif self.m_iState == STATE_ATTACK then
		if self.m_iAnim == ANIM_STRIKE then
			vm:SendViewModelMatchingSequence(vm:LookupSequence("swing1"))
		elseif self.m_iAnim == ANIM_UPPERCUT then
			vm:SendViewModelMatchingSequence(vm:LookupSequence("swing2"))
		end
	end
end
]]