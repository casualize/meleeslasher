INC_CLIENT()

local function TransferParams(base, ragdoll) -- Base is owner
	if not IsValid(base) or not IsValid(ragdoll) then return end
	ragdoll:SetModel(base:GetModel())
	ragdoll:SetPos(base:GetPos())
	ragdoll:SetAngles(base:GetAngles())
	ragdoll:SetSkin(base:GetSkin())
end

local function TransferBones(base, ragdoll) -- Base is the entity, not owner
    if not IsValid(base) or not IsValid(ragdoll) then return end
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local bone = ragdoll:GetPhysicsObjectNum(i)
		if IsValid(bone) then
			local pos, ang = base:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))
			if pos then bone:SetPos(pos) end
			if ang then bone:SetAngles(ang) end
		end
	end
end

function ENT:Initialize()
    local lseq, ldur, o, ref
    o = self:GetOwner()
    lseq, ldur = self:LookupSequence(self:GetSequenceName(self:GetSequence()))
    timer.Simple(ldur, function()
        ref = ClientsideRagdoll(o:GetModel()) -- ".. Bone access not allowed .." (developer 1 cvar), game bug?
        ref:SetOwner(o)
        TransferParams(o, ref)
        TransferBones(self, ref)
        ref:SetNoDraw(false)

        timer.Simple(8, function()
            if IsValid(ref) then
                ref:Remove()
                ref = nil
            end
        end)
    end)
end