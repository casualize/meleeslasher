local PANEL = {}

function PANEL:Init()

	self:SetSize(ScrW(),ScrH())
	self:SetZPos(0) -- -32768
	
	HealthProgress = vgui.Create("DProgress", self)
	fHealthProgress = vgui.Create("DProgress", self)
	StaminaProgress = vgui.Create("DProgress", self)
	HealthInt = vgui.Create("DLabel", HealthProgress)
	fHealthInt = vgui.Create("DLabel", fHealthProgress)
	StaminaInt = vgui.Create("DLabel", StaminaProgress)
	HealthLabel = vgui.Create("DLabel", HealthProgress)
	fHealthLabel = vgui.Create("DLabel", fHealthProgress)
	StaminaLabel = vgui.Create("DLabel", StaminaProgress)

	HealthProgress:SetSize( ScrW()*0.2, 20 )
	HealthProgress:SetPos( ScrW()/2-410, ScrH()-ScrH()/12 )
	HealthProgress:SetFraction(1)
	HealthProgress:SetZPos(1)
	
	HealthInt:SetSize(ScrW()*0.2,20)
	HealthInt:SetTextColor(Color(0,0,0))
	HealthInt:SetFont("CloseCaption_Bold")
	HealthInt:SetZPos(3)
	
	HealthLabel:SetSize(2000,20)
	HealthLabel:SetTextColor(Color(216,32,32,127))
	HealthLabel:SetFont("CloseCaption_Bold")
	HealthLabel:SetText("HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH HEALTH ")
	HealthLabel:SetZPos(2)
	
	fHealthProgress:SetSize( ScrW()*0.2, 20 )
	fHealthProgress:SetPos( ScrW()/2-200, ScrH()-ScrH()/12-40 )
	fHealthProgress:SetFraction(1)
	fHealthProgress:SetZPos(1)
	fHealthProgress:Hide()
	
	fHealthInt:SetSize(ScrW()*0.2,20)
	fHealthInt:SetTextColor(Color(0,0,0))
	fHealthInt:SetFont("CloseCaption_Bold")
	fHealthInt:SetZPos(3)
	
	fHealthLabel:SetSize(2000,20)
	fHealthLabel:SetTextColor(Color(32,32,32,255))
	fHealthLabel:SetFont("CloseCaption_Bold")
	fHealthLabel:SetZPos(2)
	
	StaminaProgress:SetSize( ScrW()*0.2, 20 )
	StaminaProgress:SetPos( ScrW()/2+10, ScrH()-ScrH()/12 )
	StaminaProgress:SetFraction(1)
	StaminaProgress:SetZPos(1)
	
	StaminaInt:SetSize(ScrW(),20)
	StaminaInt:SetTextColor(Color(0,0,0))
	StaminaInt:SetFont("CloseCaption_Bold")
	StaminaInt:SetZPos(3)
	
	StaminaLabel:SetSize(2000,20)
	StaminaLabel:SetTextColor(Color(255,127,0,127))
	StaminaLabel:SetFont("CloseCaption_Bold")
	StaminaLabel:SetText(string.lower("STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA STAMINA "))
	StaminaLabel:SetZPos(2)
	
end

function PANEL:Paint()
	
	local p = LocalPlayer()
	
	if IsValid(p) and p.m_iStamina ~= nil and p.m_iMaxStamina ~= nil then
		if p.m_eTarget != nil then
			fHealthProgress:Show()
			fHealthProgress:SetFraction(p.m_eTarget:Health()/p.m_eTarget:GetMaxHealth())
			fHealthLabel:SetText(p.m_eTarget:GetName())
			fHealthLabel:SetX(200-fHealthLabel:GetTextSize()/2)
			fHealthInt:SetText(p.m_eTarget:Health())
			else
			fHealthProgress:Hide()
		end
		HealthProgress:SetFraction(p:Health() / p:GetMaxHealth())
		HealthInt:SetText(p:Health())
		StaminaProgress:SetFraction(p.m_iStamina / p.m_iMaxStamina)
		StaminaInt:SetText(p.m_iStamina)
	
		local hx,_ = HealthLabel:GetTextSize()
		local sx,_ = StaminaLabel:GetTextSize()
		HealthLabel:SetX(CurTime()*20%(hx/2)-hx/2)
		StaminaLabel:SetX(-CurTime()*20%(sx/2)-sx/2)
		--HealthLabel:SetPos(CurTime()*(p:GetMaxHealth()-p:Health())%(hx/2)-hx/2)
		--StaminaLabel:SetPos(-CurTime()*(p.m_iMaxStamina-p.m_iStamina)%(sx/2)-sx/2)
	end
	return true
end


vgui.Register("ProgressBars",PANEL,"DPanel")