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
			local incr = FrameTime() / w.Windup
			local seq = DEF_ANM_SEQUENCES[STATE_ATTACK][w.m_iAnim]
			local seqid

			if seq ~= nil then
				seqid = ply:LookupSequence(seq .. (w.m_bFlip and "_flip" or ""))
			else
				return
			end
			
			if w.m_iState == STATE_WINDUP then -- Feint init
				w.m_flWeight = math.Approach( w.m_flWeight, 1, incr)
				ply:AddVCDSequenceToGestureSlot(0, seqid, 0, true)
				ply:AnimSetGestureWeight(0, math.ease.InOutQuad(w.m_flWeight))
				ply:AnimSetGestureWeight(1, 1 - math.ease.InOutQuad(w.m_flWeight))
			elseif w.m_iState == STATE_ATTACK then
				w.m_flWeight = 0
			elseif w.m_iState == STATE_IDLE then
				if w.m_iPrevState == STATE_WINDUP and w.m_flWeight > 0 then -- Feint cancel
					w.m_flWeight = math.Approach( w.m_flWeight, 0, incr)
					ply:AddVCDSequenceToGestureSlot(0, seqid, 0, true)
					ply:AnimSetGestureWeight(0, math.ease.InOutQuint(w.m_flWeight))
				elseif w.m_iPrevState == STATE_ATTACK then -- Recovery
					if w.m_flPrevState + w.Recovery >= CurTime() then
						w.m_flWeight = 0
						w.m_flWeightRecovery = math.Approach( w.m_flWeightRecovery, 0, incr)
						ply:AddVCDSequenceToGestureSlot(0, seqid, w.m_flCycle, true)
						ply:AnimSetGestureWeight(0, math.ease.InOutCubic(w.m_flWeightRecovery))
					end
				end
			else
				ply:AnimResetGestureSlot(0) -- wip Fixes attack anim coming out of nowhere
				ply:AnimSetGestureWeight(0, 1) -- Needed for animations like parry
			end
		end 
	end
end