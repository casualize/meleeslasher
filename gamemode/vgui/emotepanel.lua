local PANEL = {}
local slots = {}
local main

function PANEL:Init()

	self:SetSize(ScrW() / 10, ScrH() / 4)
    self:SetPos(ScrW() / 64, ScrH() / 2)
	self:SetZPos(0) -- -32768

    main = vgui.Create("DFrame", self)
    main:SetSize(self:GetSize())
    main:SetTitle("Emotes :D")
    main:ShowCloseButton(false)
    main:SetDraggable(false)

    for i = 1, 10 do
        local it = i % 10 -- Base 9
        local txt = it == 0 and "[" .. it .. "] Index further" or "nil"
        slots[it] = vgui.Create("DLabel", main)
        slots[it]:SetText(txt)
        local x, _ = main:GetSize()
        slots[it]:SetSize(x, 20)
        slots[it]:SetPos(10, (i + 1) * 20)
    end
end

function PANEL:Paint()

    local p = LocalPlayer()

    if p or p["m_bEmotePanelActive"] then
        if p.m_bEmotePanelActive ~= true then
            main:Hide()
        else
            main:Show()
            for i = 1, 9 do
                local str = DEF_EMOTE[p.m_iEmotePanelIndices * 9 + i] ~= nil and DEF_EMOTE[p.m_iEmotePanelIndices * 9 + i] or "nil"
                slots[i]:SetText("[" .. i .. "] " .. str)
            end
        end
    end
end

vgui.Register("EmotePanel", PANEL, "Panel")
