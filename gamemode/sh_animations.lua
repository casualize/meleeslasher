function GM:CalcMainActivity(ply, velocity) -- Overriden function, removed jumping, landing and walking seq. therefore, no breathing layer as well
	ply.CalcIdeal = ACT_HL2MP_RUN
	ply.CalcSeqOverride = -1

	if !( self:HandlePlayerNoClipping(ply, velocity) or
		self:HandlePlayerDriving(ply) or
		self:HandlePlayerVaulting(ply, velocity) or
		self:HandlePlayerSwimming(ply, velocity) or
		self:HandlePlayerDucking(ply, velocity) ) then -- Add parry handling?
		
		ply.CalcIdeal = ACT_MP_RUN -- GMod uses TranslateWeaponActivity method, to keep in mind later on

	end

	ply.m_bWasOnGround = ply:IsOnGround()
	ply.m_bWasNoclipping = ( ply:GetMoveType() == MOVETYPE_NOCLIP and !ply:InVehicle() )

	return ply.CalcIdeal, ply.CalcSeqOverride
end

GM.GrabEarAnimation = function() end -- Overriden function