--CACHED GLOBALS
local math = math
local bit = bit
local IN_JUMP = IN_JUMP
local IN_DUCK = IN_DUCK
local IN_ZOOM = IN_ZOOM
local FrameTime = FrameTime

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

local TimeDuckHeld = 0
function DuckJumpAlter(cmd)
	local p = LocalPlayer()
	
	if p.m_flJumpStartTime + 1 >= CurTime() or p:GetActiveWeapon().m_iState == STATE_ATTACK then
		PressJump(cmd, false)
	end

	-- Anti spaz out method A. Forces player to stay ducking until 0.5s after landing if they crouch in mid-air AND disables jumping during that time.
		-- Forces duck to be held for 0.5s after pressing it if in mid-air
	if p:OnGround() then
		TimeDuckHeld = 0
	elseif PressingDuck(cmd) then
		TimeDuckHeld = 0.9
	elseif TimeDuckHeld > 0 then
		TimeDuckHeld = TimeDuckHeld - FrameTime() -- 1 tick behind?
		PressDuck(cmd, true)
	end
end