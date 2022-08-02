INC_CLIENT()

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "Got")
	self:NetworkVarNotify("Got", function(name, old, new)
		print(name, old, new)
	end)
end

function SWEP:CalcViewModelView(vm, oP, oA)
	return oP, oA
end

function SWEP:PrimaryAttack()
	self.m_iState = STATE_ATTACK
	self.m_iAnim = ANIM_STRIKE
end