INC_SERVER()

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "Got")
end

function SWEP:m_fWindup(a_state, riposte, flip) -- m_fWindup, because the name conflicts self.Windup, a float value...
	self.m_iQueuedAnim = a_state
	self.m_bQueuedFlip = flip

	if (self.m_iState == STATE_IDLE and CurTime() >= self.m_flPrevRecovery and CurTime() >= self.m_flPrevParry and CurTime() >= self.m_flPrevFlinch) or riposte then
		local o = self:GetOwner()
		local flWindupFinal = self.Windup
		local iFlipFinal = 1
		
		if riposte then
			flWindupFinal = self.Windup * self.RiposteMulti
			o:EmitSound("physics/metal/metal_solid_impact_bullet4.wav",75,math.random(50,100),1)
		end
		iFlipFinal = flip and -1 or 1
		self:StateUpdate(o, STATE_WINDUP, a_state, riposte, flip)
		GAMEMODE:StaminaUpdate(o,nil,true)
		
		o:EmitSound("npc/vort/claw_swing" .. math.random(2) .. ".wav", 75, 125, 1)
		
		self:EyeAnglesUpdate()
		
		timer.Create("ms_attack_" .. self:EntIndex(), flWindupFinal, 1, function() if self:IsValid() then self:Attack(riposte,iFlipFinal) end end)
	end
end

local function SV_TRACER_DRAW(tracerst,traceren,bit,tracertag)
		net.Start("ms_tracer_server")
			net.WriteVector(tracerst)
			net.WriteVector(traceren)
			net.WriteUInt(bit, 2)
			net.WriteUInt(tracertag, 16)
		net.Broadcast()
end
function SWEP:DamageSimple(iAng, ent, multi)
	local dmg
	if self.m_iAnim ~= ANIM_THRUST then
		dmg = iAng > self.GlanceAngles and self.SwingDamage * multi or 2
	else
		dmg = self.ThrustDamage * multi
	end
	local d = DamageInfo()
	d:SetDamage(dmg)
	d:SetAttacker(self:GetOwner())
	d:SetInflictor(self)
	d:SetDamageType(DMG_SLASH)
	ent:TakeDamageInfo(d)
end

do
	-- Should rework this since we are now using tracehull
	local function CheckMulti(p, hitgroup)
		return hitgroup == HITGROUP_HEAD and 2 or 1
	end
	function SWEP:Attack(riposte, flip)
		local o = self:GetOwner()
		self.m_tFilter[#self.m_tFilter + 1] = o
		
		self.m_bFlip = flip == -1
		self:StateUpdate(o, STATE_ATTACK, self.m_iAnim, riposte, self.m_bFlip) -- ANIM_SKIP
		self.m_flPrevRecovery = CurTime() + self.Recovery + self.AngleStrike * self.Release
		self.slashtag = self:EntIndex()
		self:EyeAnglesUpdate()
		
		o:EmitSound(self.m_soundRelease[math.random(#self.m_soundRelease)] .. ".wav", 75, math.random(80, 100), 1)
		o:EmitSound("npc/vort/claw_swing" .. math.random(2) .. ".wav", 75, 80, 1)

		local attachment
		for i = 0, o:GetBoneCount() - 1 do
			attachment = o:GetBoneName(i)
			if attachment == "ValveBiped.Anim_Attachment_RH" then
				attachment = i
				break
			end
		end
		if not attachment then
			print("ValveBiped.Anim_Attachment_RH wasn't found!")
		end
		
		local iAngleFinal = self.m_iAnim ~= ANIM_THRUST and self.AngleStrike or 90
		local incrmul = math.floor(engine.TickInterval() / self.Release + 0.5)
		local st, en, v, a

		local iThink = 0
		local iAng = 0
		function self:Think()
			if self.m_iState == STATE_ATTACK then
				for iAng = 1, incrmul do
					o:LagCompensation(true)
					v, a = o:GetBonePosition(attachment)
					st = v + a:Up() * iAng -- Perhaps could use some sort of get for next cycle's position?
					en = st + a:Right() * -self.Range
					local tr = util.TraceLine({
						start = st,
						endpos = en,
						filter = self.m_tFilter
					})
					o:LagCompensation(false)
					if tr.HitWorld then
						self:AttackFinish(st, en, self.slashtag)
						GAMEMODE:StaminaUpdate(o,o.m_iStamina - self.StaminaDrain,true)
						o:EmitSound("physics/concrete/concrete_impact_bullet"..math.random(4)..".wav",75,100,1)
						break
					end
					if tr.Entity ~= NULL and tr.Entity ~= o then
						if type(tr.Entity) == "Player" and tr.Entity:GetActiveWeapon() then
							if tr.Entity:GetActiveWeapon().m_iState == STATE_PARRY then -- PARRY
								self:Riposte(tr.Entity) -- RIPOSTE and PARRY
								self:AttackFinish(st, en, self.slashtag)
								GAMEMODE:StaminaUpdate(o,nil,true)
								
								break
							else
								if self.Cleave then
									local bFilter = false
									for _, f in pairs(self.m_tFilter) do
										if tr.Entity == f then
											bFilter = true
											break
										end
									end
									if bFilter == false then
										self:Flinch(tr.Entity)
										GAMEMODE:StaminaUpdate(o, o.m_iStamina + 40, true)
										self:DamageSimple(iAng, tr.Entity, CheckMulti(tr.Entity,tr.HitGroup))
										
										self.m_tFilter[#self.m_tFilter + 1] = tr.Entity
									end
								else
									self:Flinch(tr.Entity)
									GAMEMODE:StaminaUpdate(o, o.m_iStamina + 40, true)
									self:DamageSimple(iAng, tr.Entity, CheckMulti(tr.Entity,tr.HitGroup))
									self:AttackFinish(st, en, self.slashtag)
									break
								end
							end
								
						elseif tr.Entity:GetClass() == ("prop_physics" or "prop_physics_multiplayer" or "func_physbox") and tr.Entity:GetPhysicsObject() then
							tr.Entity:GetPhysicsObject():SetVelocity(tr.Entity:GetVelocity() + (tr.Entity:GetPos()-tr.HitPos)*1000)
							tr.Entity:EmitSound("physics/metal/metal_barrel_impact_hard"..math.random(3)..".wav", 75, 120, 1)
							self:DamageSimple(iAng, tr.Entity, 1)
							self:AttackFinish(st, en, self.slashtag)
							GAMEMODE:StaminaUpdate(o, o.m_iStamina - self.StaminaDrain, true)
							break
						end
					end
					
					-- Draw DBG Tracers, affiliate it with glance angles
					if DRAW_SV_TRACERS:GetBool() and tr.Entity == NULL then
						local idx = 1
						if self.m_iAnim ~= ANIM_THRUST then
							idx = iAng > self.GlanceAngles and 1 or 2
						end
						SV_TRACER_DRAW(st, en, idx, self.slashtag)
					end
					if iThink + iAng >= iAngleFinal then
						self:AttackFinish()
						GAMEMODE:StaminaUpdate(o,o.m_iStamina - self.StaminaDrain,true)
						break
					end
				end
				iThink = iThink + incrmul
			end
		end
	end
end

do
	-- Defines the current sequence set for the viewmodel
	local defseq = {
		[STATE_IDLE] = {"idle"},
		[STATE_PARRY] = {"parry"},
		[STATE_WINDUP] = {
			[ANIM_NONE] = nil,
			[ANIM_STRIKE] = "windup_strike",
			[ANIM_UPPERCUT] = "windup_uppercut",
			[ANIM_UNDERCUT] = "windup_undercut",
			[ANIM_THRUST] = "windup_thrust"
		},
		-- STATE_RECOVERY will not have anims for now, also can't set its anims to ANIM_NONE due to it still being used in pmodel lua anims
		[STATE_RECOVERY] = {nil},
		[STATE_ATTACK] = {
			[ANIM_NONE] = nil,
			[ANIM_STRIKE] = "attack_strike",
			[ANIM_UPPERCUT] = "attack_uppercut",
			[ANIM_UNDERCUT] = "attack_undercut",
			[ANIM_THRUST] = "attack_thrust"
		}
	}
	function SWEP:StateUpdate(p, s, a, r, f)
		local w = p:GetActiveWeapon()
		if IsValid(w) then
			w.m_flPrevState = CurTime()
			w.m_iState = s or w.m_iState
			w.m_iAnim = a or w.m_iAnim

			if DEBUG_STATES:GetBool() then
				DBG_NCALLS = DBG_NCALLS + 1
				print(DBG_NCALLS, p, DBG_STATE[w.m_iState], DBG_ANIM[w.m_iAnim], r and "riposte" or "")
			end

			if w.m_iState == STATE_RECOVERY then
				timer.Simple(w.Windup, function()
					if IsValid(self) and not w.m_bRiposting and w.m_iState == STATE_RECOVERY then
						self:StateUpdate(p, STATE_IDLE)
					end
				end)
			end

			-- Synchronize pmodel animations with server
			local seq = DEF_ANM_SEQUENCES[w.m_iState][w.m_iAnim]
			if seq ~= nil and seq ~= "CONTINUE" then
				p:AddVCDSequenceToGestureSlot(0, p:LookupSequence(seq), 0, true)
			end

			--[[
			w:SetDTInt(WEP_STATE,s)
			w:SetDTBool(0,r or false)
			if a ~= nil and a ~= ANIM_SKIP then
				w:SetDTInt(WEP_ANIM,a)
			end
			]]

			-- Viewmodel stuff
			local vm = p:GetViewModel()
			local lseq, ldur = unpack(defseq[s][a] ~= nil and {vm:LookupSequence(defseq[s][a])} or {vm:LookupSequence(defseq[STATE_IDLE][ANIM_NONE])})
			vm:SendViewModelMatchingSequence(lseq)
			-- Not sure how unused locals impact performance
			local calcwindup = r and w.Windup * w.RiposteMulti or w.Windup
			local calcattack = a ~= ANIM_THRUST and w.Release * w.AngleStrike or w.Release * 90
			local prate = s ~= STATE_ATTACK and ldur / calcwindup or ldur / calcattack
			vm:SetPlaybackRate(prate)
			
			net.Start("ms_state_update")
				net.WriteUInt(p:UserID(), 16)
				net.WriteUInt(w.m_iState, 3)
				net.WriteUInt(w.m_iAnim or ANIM_SKIP, 3)
				net.WriteBool(r or false) -- Bitset these maybe?
				net.WriteBool(f or false)
			net.Broadcast()

			self:SetGot(w.m_iState)
		end
	end
end

function SWEP:EyeAnglesUpdate()
	if self:GetOwner() then
		net.Start("ms_ea_update")
		net.Send(self:GetOwner())
	end
end

function SWEP:AttackFinish(tracerst, traceren, tracertag)
	local o = self:GetOwner()
	
	self.m_flPrevRecovery = CurTime() + self.Recovery
	
	self:StateUpdate(o, STATE_RECOVERY, self.m_iAnim, false, self.m_bFlip)

	table.Empty(self.m_tFilter)
	self.m_bRiposting = false
	if tracerst then
		local effectdata = EffectData()
		effectdata:SetOrigin(tracerst)
		--effectdata:SetNormal(tr.HitPos:Normalize())
		util.Effect("MetalSpark", effectdata, true, false)

		if DRAW_SV_TRACERS:GetBool() then
			SV_TRACER_DRAW(tracerst, traceren, 3, tracertag)
		end
	end
end

function SWEP:Flinch(p)
	local w = p:GetActiveWeapon()
	if w.m_bRiposting then return end
	
	w.m_flPrevParry = 0.0
	w.m_flPrevFlinch = CurTime() + self.Recovery
	timer.Stop("ms_attack_" .. w:EntIndex())
	
	p:EmitSound("physics/flesh/flesh_strider_impact_bullet"..math.random(3)..".wav",75,120,1)
	p:AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_PHYSICS, true) -- Keep hitboxes synchronized with server
	net.Start("ms_player_inflict")
		net.WriteUInt(p:UserID(), 16)
	net.Broadcast()

	self:StateUpdate(p, STATE_RECOVERY, ANIM_NONE)
end

function SWEP:Riposte(p)
	p:EmitSound("physics/metal/metal_solid_impact_bullet"..math.random(2)..".wav",75,100,1)
	p:ViewPunch(Angle(-2, 0, 0))
	GAMEMODE:StaminaUpdate(p,p.m_iStamina - 7,true)
	
	local w = p:GetActiveWeapon()
	w.m_flPrevRecovery = 0.0
	w.m_flPrevParry = 0.0
	w.m_flPrevFlinch = 0.0
	
	timer.Create("ms_riposte_" .. w:EntIndex(), 1/6, 1, function()
		if w.m_iQueuedAnim ~= ANIM_NONE then
			w.m_bRiposting = true
			w:m_fWindup(w.m_iQueuedAnim, true, w.m_bQueuedFlip)
		end
	end)
	
end

function SWEP:Parry()
	if CurTime() >= self.m_flPrevParry and self.m_iState <= STATE_RECOVERY then
		local o = self:GetOwner()

		-- Reset fields
		self.m_bRiposting = false
		self.m_bQueuedFlip = false
		self.m_iQueuedAnim = ANIM_NONE
		
		self.m_flPrevParry = CurTime() + 1 + 1/3
		
		if self.m_iState == STATE_IDLE or STATE_WINDUP then
			
			o:EmitSound("physics/flesh/flesh_impact_hard3.wav", 75, 100, 1)
			
			if self.m_iState == STATE_WINDUP then
				GAMEMODE:StaminaUpdate(o, o.m_iStamina - self.FeintDrain, true) -- FTP punish
			elseif self.m_iState == STATE_IDLE then
				GAMEMODE:StaminaUpdate(o, nil, true)
			end
			
			timer.Stop("ms_attack_"..self:EntIndex())
			self:StateUpdate(o, STATE_PARRY, ANIM_NONE)
			self:EyeAnglesUpdate()
			
			timer.Simple(1/3, function()
				if not IsValid(self) or self.m_iState == STATE_WINDUP and self.m_flPrevRecovery == 0.0 then return end
				if not self.m_bRiposting then
					self:StateUpdate(o, STATE_RECOVERY, ANIM_NONE)
				end
				
				o:EmitSound("physics/flesh/flesh_impact_hard2.wav", 75, 50, 1)
			end)
		
		end
	end
end

function SWEP:Feint()
	if self.m_iState == STATE_WINDUP and not self.m_bRiposting and self:GetOwner().m_iStamina ~= 0 then
		local o = self:GetOwner()
		self:StateUpdate(o, STATE_IDLE)
		timer.Stop("ms_attack_" .. self:EntIndex())
		GAMEMODE:StaminaUpdate(o, o.m_iStamina - self.FeintDrain, true)
	end
end