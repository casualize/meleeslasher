local PANEL = {}
local ref_slot = {}
local ref_main

local x, y
function PANEL:Init()

	self:SetSize(ScrW() / 8, ScrH() / 8)
    x, y = self:GetSize()
    self:SetPos(ScrW() / 2 - x / 2, 0 * ScrH() / 20)
	self:SetZPos(0)
	
    ref_main = vgui.Create("DFrame", self)
    ref_main:SetAlpha(128)
    ref_main:SetSize(self:GetSize())
    ref_main:ShowCloseButton(false)
    ref_main:SetDraggable(false)

    for i = 1, 4 do
        ref_slot[i] = vgui.Create("DLabel", ref_main)
        ref_slot[i]:SetText("")
        ref_slot[i]:SetTextColor(Color(255,255,255))
        x, y = ref_main:GetSize()
        ref_slot[i]:SetSize(x, 20)
        ref_slot[i]:SetPos(10, (i + 0.5) * 20)
    end
end

function PANEL:Paint()

    local p = LocalPlayer()

    if p and GAMETYPE == "skirmish" and GT_SKIRMISH then
		ref_main:Show()
		ref_main:SetTitle(GAMETYPE)
		
        ref_slot[1]:SetText(GT_SKIRMISH.cl_state or "")
		
		ref_slot[2]:SetText(os.date("%M:%S", GT_SKIRMISH.cl_timeoutend - CurTime()) or "")
		
		ref_slot[3]:SetText("Red Team Wins: " .. GT_SKIRMISH.cl_tr_s or "")
		ref_slot[3]:SetTextColor(Color(255,0,0))
		
		ref_slot[4]:SetText("Blue Team Wins: " .. GT_SKIRMISH.cl_tb_s or "")
		ref_slot[4]:SetTextColor(Color(0,0,255))
	else
		ref_main:Hide()
    end
end

vgui.Register("gt_Skirmish", PANEL, "DPanel")