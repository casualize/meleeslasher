function GM:HandlePlayerDucking( ply, velocity )

	if ( !ply:IsFlagSet( FL_ANIMDUCKING ) ) then return false end

	if ( velocity:Length2DSqr() > 0.25 ) then
		ply.CalcIdeal = -1 --ACT_MP_CROUCHWALK
		ply.CalcSeqOverride = ply:LookupSequence("cwalk_ms")
	else
		ply.CalcIdeal = -1 -- ACT_MP_CROUCH_IDLE
		ply.CalcSeqOverride = ply:LookupSequence("cidle_ms")
	end

	return true
end

function GM:CalcMainActivity(ply, velocity)
	-- ply.CalcIdeal = -1 -- ACT_HL2MP_RUN
	-- ply.CalcSeqOverride = ply:LookupSequence("run_ms")

	if not self:HandlePlayerDucking(ply, velocity) then -- Add parry handling?
		ply.CalcIdeal = -1 -- ACT_MP_RUN -- GMod uses TranslateWeaponActivity method, to keep in mind later on
		ply.CalcSeqOverride = ply:LookupSequence("run_ms")
	end

	-- ply.m_bWasOnGround = ply:IsOnGround()
	-- ply.m_bWasNoclipping = ( ply:GetMoveType() == MOVETYPE_NOCLIP and not ply:InVehicle() )

	return ply.CalcIdeal, ply.CalcSeqOverride
end

-- Updates movement playbackrate?
function GM:UpdateAnimation( ply, velocity, maxseqgroundspeed )
	local len = velocity:Length()
	local rate = math.min( len > 0.2 and len / maxseqgroundspeed or 1.0, 2 )

	-- if we're under water we want to constantly be swimming..
	if ( ply:WaterLevel() >= 2 ) then
		rate = math.max( rate, 0.5 )
	elseif ( !ply:IsOnGround() and len >= 1000 ) then
		rate = 0.1
	end

	ply:SetPlaybackRate( rate )
end

do -- Does this even do anything?
	local overridet = {
		"GrabEarAnimation",
		"MouthMoveAnimation",
		"HandlePlayerDriving",
		"HandlePlayerLanding",
		"HandlePlayerSwimming",
		"HandlePlayerVaulting",
		"HandlePlayerNoClipping",
		"HandlePlayerJumping"
	}
	for _, k in ipairs(overridet) do
		GM[k] = function() end
	end
end