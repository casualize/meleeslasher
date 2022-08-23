local PANEL = {}
local ref_slot = {}
local ref_main

local x, y
function PANEL:Init()

	self:SetSize((ScrW() / 8) * (GAME_NTEAMS < 6 and GAME_NTEAMS or 6), ScrW() / 8)
    x, y = self:GetSize()
    self:SetPos(ScrW() / 2 - x / 2, ScrH() / 2)
	self:SetZPos(0)

    self:MakePopup()

    ref_main = vgui.Create("DFrame", self)
    ref_main:SetAlpha(128)
    ref_main:SetSize(self:GetSize())
    ref_main:ShowCloseButton(false)
    ref_main:SetDraggable(false)

    for i = 1, GAME_NTEAMS do
        local col = GAME_TEAMCTABLE[i] ~= nil and GAME_TEAMCTABLE[i] or Color(0, 0, 0)
        ref_slot[i] = vgui.Create("DButton", ref_main)
        ref_slot[i]:SetText("TEAM " .. i)
        ref_slot[i]:SetTextColor(col)
        x, y = ref_main:GetSize()
        ref_slot[i]:SetSize(x / GAME_NTEAMS, y)
        x, y = ref_slot[i]:GetSize()
        ref_slot[i]:SetPos((i - 1) * x, 0)
        local doubleref = ref_slot[i]
        function doubleref:DoClick()
            net.Start("ms_team_update")
                net.WriteUInt(i, 8)
            net.SendToServer()

            -- lol
            self:GetParent():GetParent():KillFocus()
            self:GetParent():GetParent():SetKeyboardInputEnabled(false)
            self:GetParent():GetParent():SetMouseInputEnabled(false)
            self:GetParent():GetParent():Remove()
        end
    end
end

function PANEL:Paint()

end

vgui.Register("TeamSelect", PANEL, "DPanel")