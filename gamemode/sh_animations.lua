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
	if not self:HandlePlayerDucking(ply, velocity) then -- Add parry handling?
		ply.CalcIdeal = -1 -- ACT_MP_RUN -- GMod uses TranslateWeaponActivity method, to keep in mind later on
		ply.CalcSeqOverride = ply:LookupSequence("run_ms")
	end
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

	if CLIENT then
		local w = ply:GetActiveWeapon()
		if IsValid(w) and w.m_flWeight then
			if w.m_iState == STATE_RECOVERY then
				w.m_flWeight = w.m_flWeight or 1
				local seq = DEF_ANM_SEQUENCES[STATE_ATTACK][w.m_iAnim]
				w.m_flWeight = math.Approach( w.m_flWeight, 0, FrameTime() * w.Windup * 2)
				if seq ~= nil then
					ply:AddVCDSequenceToGestureSlot(0, ply:LookupSequence(seq), w.m_flCycle, true)
					ply:AnimSetGestureWeight(0, w.m_flWeight)
				end
			elseif w.m_iState == STATE_WINDUP then
				w.m_flWeight = w.m_flWeight or 0
				local seq = DEF_ANM_SEQUENCES[STATE_ATTACK][w.m_iAnim]
				w.m_flWeight = math.Approach( w.m_flWeight, 1, FrameTime() * w.Windup * 2)
				if seq ~= nil then
					ply:AddVCDSequenceToGestureSlot(0, ply:LookupSequence(seq), 0, true)
					ply:AnimSetGestureWeight(0, math.ease.InOutQuad(w.m_flWeight))
				end
			elseif w.m_flWeight > 0 then
				if w.m_iState == STATE_IDLE then
					w.m_flWeight = w.m_flWeight or 0
					local seq = DEF_ANM_SEQUENCES[STATE_ATTACK][w.m_iAnim]
					w.m_flWeight = math.Approach( w.m_flWeight, 0, FrameTime() * w.Windup * 2)
					if seq ~= nil then
						ply:AddVCDSequenceToGestureSlot(0, ply:LookupSequence(seq), 0, true)
						ply:AnimSetGestureWeight(0, w.m_flWeight)
					end
				end
			else
				-- ply:AnimSetGestureWeight(0, 1)
			end
		end 
	end
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