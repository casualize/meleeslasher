INC_SERVER()
-- TODO: Modify the physics of ent so it simulates falling when the ent is spawned in air
function ENT:Initialize()
    o = self:GetOwner()
    if not IsValid(o) then return end

    self:SetPos(o:GetPos())
    self:SetAngles(o:GetAngles())
    self:SetModel(o:GetModel())

    local mr = math.random(1, 4)
    local lseq, ldur = self:LookupSequence("death_0" .. mr)
    self:ResetSequenceInfo()
    self:SetSequence(lseq)
    self:SetPlaybackRate(1)
    self.AutomaticFrameAdvance = true
    timer.Simple(ldur, function()
        self:SetNoDraw(true)
        timer.Simple(1, function()
            self:Remove()
        end)
    end)
end

function ENT:Think()
    self:NextThink(CurTime())
    return true
end