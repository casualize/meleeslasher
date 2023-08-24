INC_SERVER()

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Int", 1, "Anim")
	self:NetworkVar("Bool", 0, "Riposte")
	self:NetworkVar("Bool", 1, "Flip")

	self:NetworkVar("Bool", 2, "Success") -- For lp anim
end

function SWEP:Initialize()
	local o = self:GetOwner()

	-- Internal fields
	self.m_nThink = 0
	self.m_iAngleFinal = 0
	self.m_iIncrMul = 0
	self.m_iAttachID = 0
	self.m_iSeqID = 0
end

function SWEP:Queue(ianim, bflip)
	local o = self:GetOwner()
	o:AnimResetGestureSlot(GESTURE_SLOT_VCD) -- Emotes

	self.m_iQueuedAnim = ianim -- ?
	self.m_bQueuedFlip = bflip
	
	-- Note, this still could pass ANIM_NONE
	if (self.m_iState == STATE_IDLE and self.m_flPrevState + self.Windup <= CurTime() ) or self.m_bRiposting then
		
		if self.m_bRiposting then
			self:EmitSound("physics/metal/metal_solid_impact_bullet4.wav", 75, math.random(50, 100), 1)
		end

		self.m_bFlip = bflip
		self:StateUpdate(o, STATE_WINDUP, ianim, self.m_bRiposting, bflip)
		GAMEMODE:StaminaUpdate(o, nil, true)
		
		o:EmitSound("npc/vort/claw_swing" .. math.random(2) .. ".wav", 75, 125, 1)
		
		self.m_flNextAttack = CurTime() + self.Windup
	end
end

local function SV_TRACER_DRAW(tracerst, traceren, bit, tracertag)
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

function SWEP:Attack()
	local o = self:GetOwner()
	self.m_tFilter[#self.m_tFilter + 1] = o
	
	self.slashtag = self:EntIndex()
	self.m_iAngleFinal = self.m_iAnim ~= ANIM_THRUST and self.AngleStrike or 90 -- Call this elsewhere
	self.m_iIncrMul = math.floor(engine.TickInterval() / self.Release + 0.5) -- Call this elsewhere
	
	o:EmitSound(self.m_soundRelease[math.random(#self.m_soundRelease)] .. ".wav", 75, math.random(80, 100), 1)
	self:EmitSound("npc/vort/claw_swing" .. math.random(2) .. ".wav", 75, 80, 1)

	for i = 0, o:GetBoneCount() - 1 do
		self.m_iAttachID = o:GetBoneName(i) -- Temporarily set it to a string
		if self.m_iAttachID == "ValveBiped.Anim_Attachment_RH" then
			self.m_iAttachID = i
			break
		end
	end
	if not self.m_iAttachID then
		print("ValveBiped.Anim_Attachment_RH wasn't found!")
	end

	self:StateUpdate(o, STATE_ATTACK, self.m_iAnim, self.m_bRiposting, self.m_bFlip) -- The packets will not be sent to clients if the first iteration calls attackfinish ?

	self.m_iQueuedAnim = ANIM_NONE
	self.m_bQueuedFlip = false
end

function SWEP:CheckMulti(p, hitgroup)
	local o = self:GetOwner()
	local amount = hitgroup == HITGROUP_HEAD and 2 or 1
	return o:Team() ~= p:Team() and amount or amount * 0.2
end
function SWEP:Think()
	local o = self:GetOwner()
	if self.m_iState == STATE_IDLE then
		--[[if self.m_flPrevState + self.Recovery >= CurTime() then
			self.m_iQueuedAnim = ANIM_NONE
		end]]
		if self.m_iQueuedAnim ~= ANIM_NONE then
			self:Queue(self.m_iQueuedAnim, self.m_bQueuedFlip)
		end
	elseif self.m_iState == STATE_WINDUP and self.m_flNextAttack <= CurTime() then
		self:Attack()
	elseif self.m_iState == STATE_PARRY then
		if self.m_flPrevRiposte >= CurTime() then
			if self.m_iQueuedAnim ~= ANIM_NONE then
				self.m_bRiposting = true
				self:Queue(self.m_iQueuedAnim, self.m_bQueuedFlip)
			end
		elseif self.m_flPrevState + (1/3) <= CurTime() then
			if not self.m_bRiposting then
				self.m_iQueuedAnim = ANIM_NONE
				self:StateUpdate(o, STATE_IDLE, ANIM_NONE, self.m_bRiposting, self.m_bFlip)
				o:EmitSound("physics/flesh/flesh_impact_hard2.wav", 75, 50, 1)
			end
		end
	elseif self.m_iState == STATE_ATTACK then
		for iAng = 1, (self.Range - self.HandleRange)/4 do -- self.m_iIncrMul
			if self.m_iSeqID ~= nil  then
				o:AddVCDSequenceToGestureSlot(0, self.m_iSeqID, (self.m_nThink + iAng) / self.m_iAngleFinal, true) -- Setting gesture here allows manipulating the "playback rate"
			end
			o:LagCompensation(true)
			local bm = o:GetBoneMatrix(self.m_iAttachID) -- The returns are fixed on tick...
			local v = bm:GetTranslation()
			local a = bm:GetAngles()
			local back = self.m_iAnim ~= ANIM_THRUST and -(self.Range - self.HandleRange)/2 or 1
			local back2 = self.m_nThink > 32 and back or 1
			local st = v + a:Right() * -8 + a:Right() * -iAng * 4 -- Chiv1 way of doing it, need to make it dynamic based on tickrate etc
			local en = st + a:Up() * back2
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
					if tr.Entity:GetActiveWeapon().m_iState == STATE_PARRY or o:Team() == tr.Entity:Team() then -- PARRY
						if tr.Entity:GetActiveWeapon().m_iState == STATE_PARRY then
							self:Riposte(tr.Entity) -- RIPOSTE and PARRY
						else
							self:DamageSimple(iAng, tr.Entity, self:CheckMulti(tr.Entity,tr.HitGroup))
						end
						GAMEMODE:StaminaUpdate(o, nil, true)
						self:AttackFinish(st, en, self.slashtag)
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
							if not bFilter then
								self:Flinch(tr.Entity)
								GAMEMODE:StaminaUpdate(o, o.m_iStamina + 40, true)
								self:DamageSimple(iAng, tr.Entity, self:CheckMulti(tr.Entity,tr.HitGroup))
								
								self.m_tFilter[#self.m_tFilter + 1] = tr.Entity
							end
						else
							self:Flinch(tr.Entity)
							GAMEMODE:StaminaUpdate(o, o.m_iStamina + 40, true)
							self:DamageSimple(iAng, tr.Entity, self:CheckMulti(tr.Entity,tr.HitGroup))
							self:AttackFinish(st, en, self.slashtag)
							break
						end
					end
						
				elseif tr.Entity:GetClass() == ("prop_physics_multiplayer" or "prop_physics" or "func_physbox") and tr.Entity:GetPhysicsObject() then -- the "or"s seem not to work
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
			if self.m_nThink + iAng > self.m_iAngleFinal then
				self:AttackFinish()
				GAMEMODE:StaminaUpdate(o,o.m_iStamina - self.StaminaDrain,true)
				break
			end
		end
		self.m_nThink = self.m_nThink + self.m_iIncrMul
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
		[STATE_ATTACK] = {
			[ANIM_NONE] = nil,
			[ANIM_STRIKE] = "attack_strike",
			[ANIM_UPPERCUT] = "attack_uppercut",
			[ANIM_UNDERCUT] = "attack_undercut",
			[ANIM_THRUST] = "attack_thrust"
		}
	}
	-- This will update the specific player's wep, not self!
	function SWEP:StateUpdate(p, s, a, r, f)
		local w = p:GetActiveWeapon()
		if IsValid(w) then
			w.m_flPrevState = CurTime()

			w.m_iState = s
			w.m_iAnim = a
			w.m_bRiposting = r
			w.m_bFlip = f

			w:SetState(s or w.m_iState)
			w:SetAnim(a or w.m_iAnim)
			w:SetRiposte(r or false)
			w:SetFlip(f or false)

			if DEBUG_STATES:GetBool() then
				DBG_NCALLS = DBG_NCALLS + 1
				print(DBG_NCALLS, p, DBG_STATE[w.m_iState], DBG_ANIM[w.m_iAnim], r and "riposte" or "")
			end

			local seq = DEF_ANM_SEQUENCES[w.m_iState][w.m_iAnim]
			self.m_iSeqID = seq ~= nil and p:LookupSequence(seq .. (f and "_flip" or "")) or nil

			-- Viewmodel stuff, unused
			--[[
				local vm = p:GetViewModel()
				local lseq, ldur = unpack(defseq[s][a] ~= nil and {vm:LookupSequence(defseq[s][a])} or {vm:LookupSequence(defseq[STATE_IDLE][ANIM_NONE])})
				vm:SendViewModelMatchingSequence(lseq)
				local calcattack = a ~= ANIM_THRUST and w.Release * w.AngleStrike or w.Release * 90
				local prate = s ~= STATE_ATTACK and ldur / w.Windup or ldur / calcattack
				vm:SetPlaybackRate(prate)
			]]
		end
	end
end

function SWEP:AttackFinish(tracerst, traceren, tracertag)
	local o = self:GetOwner()

	self.m_nThink = 0
	
	self:StateUpdate(o, STATE_IDLE, self.m_iAnim, false, self.m_bFlip)

	table.Empty(self.m_tFilter)
	self.m_bRiposting = false
	if tracerst then
		local effectdata = EffectData()
		effectdata:SetOrigin(traceren)
		util.Effect("MetalSpark", effectdata, true, true)

		if DRAW_SV_TRACERS:GetBool() then
			SV_TRACER_DRAW(tracerst, traceren, 3, tracertag)
		end
	end
end

function SWEP:Flinch(p)
	local w = p:GetActiveWeapon()
	if w.m_bRiposting then return end
	
	w.m_flPrevParry = 0.0

	w.m_iQueuedAnim = ANIM_NONE
	w.m_bQueuedFlip = false
	
	p:EmitSound("physics/flesh/flesh_strider_impact_bullet"..math.random(3)..".wav", 75, 120, 1)
	p:AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_PHYSICS, true) -- Keep hitboxes synchronized with server
	net.Start("ms_player_inflict")
		net.WriteUInt(p:UserID(), 16)
		net.WriteFloat(CurTime())
	net.Broadcast()

	self:StateUpdate(p, STATE_IDLE, w.m_iAnim, false, w.m_bFlip)
end

function SWEP:Riposte(p)
	p:EmitSound("physics/metal/metal_solid_impact_bullet"..math.random(2)..".wav",75,100,1)
	p:ViewPunch(Angle(-2, 0, 0))
	GAMEMODE:StaminaUpdate(p,p.m_iStamina - 7,true)
	
	local w = p:GetActiveWeapon()
	w.m_flPrevParry = 0.0
	w.m_flPrevRiposte = CurTime() + 1/6
	w:SetSuccess(not w:GetSuccess()) -- For cl anim
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end
	self:Parry()
end

function SWEP:Parry()
	if self.m_flPrevParry <= CurTime() and (self.m_iState == STATE_IDLE or self.m_iState == STATE_WINDUP) then
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

			self:StateUpdate(o, STATE_PARRY, ANIM_NONE, false, self.m_bFlip)
		end
	end
end

function SWEP:Feint()
	if self.m_iState == STATE_WINDUP and not self.m_bRiposting and self:GetOwner().m_iStamina ~= 0 then
		local o = self:GetOwner()
		self.m_iQueuedAnim = ANIM_NONE
		self:StateUpdate(o, STATE_IDLE, self.m_iAnim, false, self.m_bFlip)
		GAMEMODE:StaminaUpdate(o, o.m_iStamina - self.FeintDrain, true)
	end
end