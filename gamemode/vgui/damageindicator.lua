local PANEL = {}
local ref_slot = {}
local ref_main

local x, y
function PANEL:Init()

	self:SetSize(ScrW() / 4, ScrH() / 4.5)
    x, y = self:GetSize()
    self:SetPos(ScrW() / 2 - x / 2, 13 * ScrH() / 20)
	self:SetZPos(0) -- -32768

    ref_main = vgui.Create("DFrame", self)
    ref_main:SetAlpha(128)
    ref_main:SetSize(self:GetSize())
    ref_main:ShowCloseButton(false)
    ref_main:SetDraggable(false)

    for i = 1, 10 do
        ref_slot[i] = vgui.Create("DLabel", ref_main)
        ref_slot[i]:SetText("")
        ref_slot[i]:SetTextColor(Color(0,255,0))
        x, y = ref_main:GetSize()
        ref_slot[i]:SetSize(x, 20)
        ref_slot[i]:SetPos(10, (i + 0.5) * 20)
    end
end

function PANEL:Paint()

    local p = LocalPlayer()

    if p then
        if #DMG_DATA ~= 0 then
            local dmgtotal = 0
            ref_main:Show()
            for k ,v in ipairs(DMG_DATA) do
                -- Hate doing these tasks inside panel hooks ...
                if v[3] <= CurTime() then
                    table.remove(DMG_DATA, k)
                end
                dmgtotal = dmgtotal + v[2]
            end
            ref_main:SetTitle("Total: " .. dmgtotal)
            for i = 1, 10 do
                local txt = DMG_DATA[i] ~= nil and ("+" .. DMG_DATA[i][2] .. " " .. Player(DMG_DATA[i][1]):Nick()) or ""
                local alpha = DMG_DATA[i] ~= nil and math.Clamp(255 - 75 * (1 / (DMG_DATA[i][3] - CurTime())), 0, 255) or 255
                ref_slot[i]:SetText(txt)
                ref_slot[i]:SetAlpha(alpha)
            end
        else
            ref_main:Hide()
        end
    end
end

vgui.Register("DamageIndicator", PANEL, "DPanel")