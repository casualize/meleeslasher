local PANEL = {}
local ref_slot = {}
local ref_main

function PANEL:Init()

	self:SetSize(ScrW() / 10, ScrH() / 4)
    self:SetPos(ScrW() / 64, ScrH() / 2)
	self:SetZPos(0) -- -32768

    ref_main = vgui.Create("DFrame", self)
    ref_main:SetSize(self:GetSize())
    ref_main:SetTitle("Emotes :D")
    ref_main:ShowCloseButton(false)
    ref_main:SetDraggable(false)

    for i = 1, 10 do
        local it = i % 10 -- Base 9
        local txt = it == 0 and "[" .. it .. "] Index further" or "nil"
        ref_slot[it] = vgui.Create("DLabel", ref_main)
        ref_slot[it]:SetText(txt)
        local x, _ = ref_main:GetSize()
        ref_slot[it]:SetSize(x, 20)
        ref_slot[it]:SetPos(10, (i + 1) * 20)
    end
end

function PANEL:Paint()

    local p = LocalPlayer()

    if p or p["m_bEmotePanelToggle"] then
        if p.m_bEmotePanelToggle ~= true then
            ref_main:Hide()
        else
            ref_main:Show()
            for i = 1, 9 do
                local str = DEF_EMOTE[p.m_iEmotePanelIndices * 9 + i] ~= nil and DEF_EMOTE[p.m_iEmotePanelIndices * 9 + i] or "nil"
                ref_slot[i]:SetText("[" .. i .. "] " .. str)
            end
        end
    end
end

vgui.Register("EmotePanel", PANEL, "Panel")