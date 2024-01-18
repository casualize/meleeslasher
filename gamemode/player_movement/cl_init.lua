local function PressingJump(cmd)
	return bit.band(cmd:GetButtons(), IN_JUMP) ~= 0
end

local function PressingDuck(cmd)
	return bit.band(cmd:GetButtons(), IN_DUCK) ~= 0
end

local function PressJump(cmd, press)
	if press then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
	elseif PressingJump(cmd) then
		cmd:SetButtons(cmd:GetButtons() - IN_JUMP)
	end
end

local function PressDuck(cmd, press)
	if press then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_DUCK))
	elseif PressingDuck(cmd) then
		cmd:SetButtons(cmd:GetButtons() - IN_DUCK)
	end
end

function Movement(cmd)
	local p = LocalPlayer()

	PressDuck(cmd, false)

	if p.m_flJumpStartTime + 1 >= CurTime() or p:GetActiveWeapon().m_iState == STATE_ATTACK then
		PressJump(cmd, false)
	end
end