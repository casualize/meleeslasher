local PANEL = {}

local HEALTH = 1
local TARGET = 2
local STAMINA = 3

local MAIN = 1
local SCROLL = 2
local INFO = 3

local ref = {
	[HEALTH] = {true, true, true},
	[TARGET] = {true, true, true},
	[STAMINA] = {true, true, true}
}
local ctable = {
	[1] = Color(0, 0, 0, 255),
	[2] = Color(32, 32, 32, 255),
	[3] = Color(216, 32, 32, 128),
	[4] = Color(255, 128, 0, 128)
}

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetZPos(0)
	
	for _, v in ipairs(ref) do
		v[MAIN] = vgui.Create("DProgress", self)
		v[MAIN]:SetSize(ScrW()*0.2, 20)
		v[MAIN]:SetFraction(1)
		v[MAIN]:SetZPos(1)

		v[INFO] = vgui.Create("DLabel", v[MAIN])
		v[INFO]:SetSize(v[MAIN]:GetSize())
		v[INFO]:SetTextColor(ctable[1])
		v[INFO]:SetFont("CloseCaption_Bold")
		v[INFO]:SetZPos(3)

		v[SCROLL] = vgui.Create("DLabel", v[MAIN])
		v[SCROLL]:SetSize(2000, 20)
		v[SCROLL]:SetFont("CloseCaption_Bold")
		v[SCROLL]:SetZPos(2)
	end
	
	ref[TARGET][MAIN]:SetPos(ScrW()/2-200, ScrH()-ScrH()/12-40)
	ref[STAMINA][MAIN]:SetPos(ScrW()/2+10, ScrH()-ScrH()/12)
	ref[HEALTH][MAIN]:SetPos(ScrW()/2-410, ScrH()-ScrH()/12)
	
	ref[TARGET][SCROLL]:SetTextColor(ctable[2])
	ref[HEALTH][SCROLL]:SetTextColor(ctable[3])
	ref[STAMINA][SCROLL]:SetTextColor(ctable[4])

	ref[HEALTH][SCROLL]:SetText("HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH ")
	ref[STAMINA][SCROLL]:SetText(string.lower("STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA "))
	
	ref[TARGET][MAIN]:Hide()
end

function PANEL:Paint()
	
	local p = LocalPlayer()
	
	if IsValid(p) and p.m_iStamina ~= nil and p.m_iMaxStamina ~= nil then
		if p.m_eTarget ~= nil then
			ref[TARGET][MAIN]:Show()
			ref[TARGET][MAIN]:SetFraction(p.m_eTarget:Health()/p.m_eTarget:GetMaxHealth())
			ref[TARGET][SCROLL]:SetText(p.m_eTarget:GetName())
			ref[TARGET][SCROLL]:SetX(200-ref[TARGET][SCROLL]:GetTextSize()/2)
			ref[TARGET][INFO]:SetText(p.m_eTarget:Health())
			else
			ref[TARGET][MAIN]:Hide()
		end
		ref[HEALTH][MAIN]:SetFraction(p:Health() / p:GetMaxHealth())
		ref[HEALTH][INFO]:SetText(p:Health())
		ref[STAMINA][MAIN]:SetFraction(p.m_iStamina / p.m_iMaxStamina)
		ref[STAMINA][INFO]:SetText(p.m_iStamina)
	
		local hx,_ = ref[HEALTH][SCROLL]:GetTextSize()
		local sx,_ = ref[STAMINA][SCROLL]:GetTextSize()
		ref[HEALTH][SCROLL]:SetX(CurTime()*20%(hx/2)-hx/2)
		ref[STAMINA][SCROLL]:SetX(-CurTime()*20%(sx/2)-sx/2)
	end
	return true
end


vgui.Register("ProgressBars", PANEL, "DPanel")