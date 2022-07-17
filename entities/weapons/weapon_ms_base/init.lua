INC_SERVER()

function SWEP:m_fWindup(a_state, riposte, flip) -- m_fWindup, because the name conflicts self.Windup, a float value...
	self.m_iQueuedAnim = a_state
	self.m_bQueuedFlip = flip

	if (self.m_iState == STATE_IDLE and CurTime() >= self.m_flPrevRecovery and CurTime() >= self.m_flPrevParry and CurTime() >= self.m_flPrevFlinch) or riposte then
		local flWindupFinal = self.Windup
		local iFlipFinal = 1
		local o = self:GetOwner()
		
		if riposte then
			flWindupFinal = self.Windup * self.RiposteMulti
			o:EmitSound("physics/metal/metal_solid_impact_bullet4.wav",75,math.random(50,100),1)
		end
		iFlipFinal = flip and -1 or 1
		self:StateUpdate(o, STATE_WINDUP, a_state, riposte, flip)
		GAMEMODE:StaminaUpdate(o,nil,true)
		
		o:EmitSound("npc/vort/claw_swing"..math.random(2)..".wav",75,125,1)
		
		self:SetHoldType(self.WindupAnim)
		self:EyeAnglesUpdate()
		
		timer.Create("ms_attack_"..self:EntIndex(),flWindupFinal,1,function() if self:IsValid() then self:Attack(riposte,iFlipFinal) end end)
	end
end

local function SV_TRACER_DRAW(tracerst,traceren,bit,tracertag)
	if DRAW_SV_TRACERS:GetBool() then
		net.Start("ms_tracer_server")
			net.WriteVector(tracerst)
			net.WriteVector(traceren)
			net.WriteUInt(bit,2)
			net.WriteUInt(tracertag,16)
		net.Broadcast()
	end
end
local function CalcSlashAttack(p, w, inv, rot, flip, it)
	local ea = p:EyeAngles()
	local ep = p:EyePos()
	local normal = Angle(w.AngleStrikeOffset*inv-ea[1]+it*inv,180+ea[2],0)
	normal:RotateAroundAxis(ea:Forward(),rot)
	local st = ep + normal:Forward() * 32 + normal:Right() * 8*inv*flip -- Right is UP(?)
	local en = ep + normal:Forward() * (32 + w.Range) + normal:Right() * 8*inv*flip
	return st, en
end
local function CheckMulti(p,hitgroup)
	local multi = 1
	if hitgroup == HITGROUP_HEAD then
		multi = 2.0
		p:EmitSound("npc/antlion/shell_impact"..math.random(4)..".wav",75,90,1)
	elseif hitgroup >= HITGROUP_CHEST and hitgroup <= HITGROUP_RIGHTARM then
		multi = 1.0
	elseif hitgroup == HITGROUP_LEFTLEG or HITGROUP_RIGHTLEG then
		multi = 0.7
	end
	return multi
end
function SWEP:DamageSimple(iAng,ent,multi)
	local d = DamageInfo()
	if iAng > self.GlanceAngles then
		d:SetDamage(self.SwingDamage*multi)
	else 
		d:SetDamage(2) 
	end
	if self.m_iAnim == ANIM_THRUST then
		d:SetDamage(self.ThrustDamage*multi)
	end
	d:SetAttacker(self:GetOwner())
	d:SetInflictor(self)
	d:SetDamageType(DMG_SLASH)
	ent:TakeDamageInfo(d)
end

function SWEP:Attack(riposte, flip)
	local o = self:GetOwner()
	self.m_tFilter[#self.m_tFilter + 1] = o
	
	self.m_bFlip = flip == -1
	self:StateUpdate(o, STATE_ATTACK, self.m_iAnim, riposte, self.m_bFlip) -- ANIM_SKIP
	self.m_flPrevRecovery = CurTime() + self.Recovery + self.AngleStrike * self.Release
	self.slashtag = self:EntIndex()
	self:EyeAnglesUpdate()
	
	o:EmitSound(self.m_soundRelease[math.random(#self.m_soundRelease)]..".wav",75,math.random(80,100),1)
	o:EmitSound("npc/vort/claw_swing"..math.random(2)..".wav",75,80,1)
	
	local iAngleFinal = self.AngleStrike
	if self.m_iAnim == ANIM_THRUST then
		iAngleFinal = 90
	end
	for iAng = 0,iAngleFinal do
		timer.Simple(self.Release * iAng, function()
			if o:IsValid() and self.m_iState == STATE_ATTACK then
				local ea = o:EyeAngles()
				local ep = o:EyePos()
				--local forward = Angle(Angle(-ea.p*math.cos(iAng * (math.pi/180)),ea.y,0)-Angle(0,self.AngleStrikeOffset,0)+Angle(0,iAng,0)):Forward()
				--local forward = Angle(Angle(0,ea.y+iAng-self.AngleStrikeOffset,0)):Forward() + Vector(0,0,ea.p/60*math.cos(iAng * (math.pi/180)))
				--local forward = Angle(Angle(0,ea.y+iAng-self.AngleStrikeOffset,0)):Forward() + Vector(0,0,ea.p/60*math.cos((360/(self.AngleStrikeOffset/iAng)-180) * (math.pi/180)))
				local st, en
				if self.m_iAnim == ANIM_STRIKE then
					st, en = CalcSlashAttack(o,self,-1,90*flip,flip,iAng)
				elseif self.m_iAnim == ANIM_UPPERCUT then
					st, en = CalcSlashAttack(o,self,-1,45*flip,flip,iAng)
				elseif self.m_iAnim == ANIM_UNDERCUT then
					st, en = CalcSlashAttack(o,self,1,-45*flip,flip,iAng)
				elseif self.m_iAnim == ANIM_THRUST then
					local normal = Angle(Angle(ea[1] + math.cos(math.rad(270*iAng/iAngleFinal)) * 2,ea[2] - math.sin(math.rad(270*iAng/iAngleFinal)) * 2*flip,0))
					st = ep + normal:Forward() * (32+6*(iAng/iAngleFinal)) + normal:Up() * -8 + normal:Right() * 8*flip
					en = ep + normal:Forward() * ((32 + self.Range)+6*(iAng/iAngleFinal)) + normal:Up() * -8 + normal:Right() * 8*flip
				end
				o:LagCompensation(true)
				local tr = util.TraceHull({
					start = st,
					endpos = en,
					filter = self.m_tFilter,
				})
				o:LagCompensation(false)
				if tr.HitWorld then
					self:AttackFinish(true,st,en,self.slashtag)
					GAMEMODE:StaminaUpdate(o,o.m_iStamina - self.StaminaDrain,true)
					o:EmitSound("physics/concrete/concrete_impact_bullet"..math.random(4)..".wav",75,100,1)
					return
				end
				if tr.Entity ~= NULL and tr.Entity ~= o then
					if tr.Entity:GetClass() == "player" and tr.Entity:GetActiveWeapon() then
						if tr.Entity:GetActiveWeapon().m_iState == STATE_PARRY then -- PARRY
							self:Riposte(tr.Entity) -- RIPOSTE and PARRY
							self:AttackFinish(true,st,en,self.slashtag)
							GAMEMODE:StaminaUpdate(o,nil,true)
							self:SetHoldType(self.IdleAnim)
							
							local effectdata = EffectData()
							effectdata:SetOrigin(tr.HitPos)
							--effectdata:SetNormal(tr.HitPos:Normalize())
							util.Effect("MetalSpark", effectdata, true,false)
							
							return
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
									GAMEMODE:StaminaUpdate(o,o.m_iStamina + 40,true)
									self:DamageSimple(iAng,tr.Entity,CheckMulti(tr.Entity,tr.HitGroup))
									
									self.m_tFilter[#self.m_tFilter + 1] = tr.Entity
								end
							else
								self:Flinch(tr.Entity)
								GAMEMODE:StaminaUpdate(o,o.m_iStamina + 40,true)
								self:DamageSimple(iAng,tr.Entity,CheckMulti(tr.Entity,tr.HitGroup))
								self:AttackFinish(true,st,en,self.slashtag)
								return
							end
						end
							
					elseif tr.Entity:GetClass() == ("prop_physics" or "prop_physics_multiplayer" or "func_physbox") and tr.Entity:GetPhysicsObject() then
						tr.Entity:GetPhysicsObject():SetVelocity(tr.Entity:GetVelocity() + (tr.Entity:GetPos()-tr.HitPos)*1000)
						tr.Entity:EmitSound("physics/metal/metal_barrel_impact_hard"..math.random(3)..".wav",75,120,1)
						self:DamageSimple(iAng,tr.Entity,1)
						self:AttackFinish(true,st,en,self.slashtag)
						GAMEMODE:StaminaUpdate(o,o.m_iStamina - self.StaminaDrain,true)
						return
					end
				end
				if tr.Entity == NULL then
					if self.m_iAnim ~= ANIM_THRUST then
						if iAng > self.GlanceAngles then
							SV_TRACER_DRAW(st,en,1,self.slashtag)
							else
							SV_TRACER_DRAW(st,en,2,self.slashtag)
						end
						else
						SV_TRACER_DRAW(st,en,1,self.slashtag)
					end
				end
				
				if iAng == iAngleFinal then
					self:AttackFinish(false)
					GAMEMODE:StaminaUpdate(o,o.m_iStamina - self.StaminaDrain,true)
					return
				end
			end
		end)
	end
end

do
	local defseq = {
		[STATE_IDLE] = {"idle"},
		[STATE_PARRY] = {"parry"},
		[STATE_WINDUP] = {
			[ANIM_NONE] = "idle",
			[ANIM_STRIKE] = "windup_strike",
			[ANIM_UPPERCUT] = "windup_uppercut",
			[ANIM_UNDERCUT] = "windup_undercut",
			[ANIM_THRUST] = "windup_thrust"
		},
		-- STATE_RECOVERY will not have anims for now, also can't set its anims to ANIM_NONE due to it still being used in pmodel lua anims
		[STATE_RECOVERY] = "idle",
		[STATE_ATTACK] = {
			[ANIM_NONE] = "idle",
			[ANIM_STRIKE] = "attack_strike",
			[ANIM_UPPERCUT] = "attack_uppercut",
			[ANIM_UNDERCUT] = "attack_undercut",
			[ANIM_THRUST] = "attack_thrust"
		}
	}
	function SWEP:StateUpdate(p, s, a, r, f)
		local w = p:GetActiveWeapon()
		w.m_flPrevState = CurTime()
		w.m_iState = s
		--if a ~= (ANIM_SKIP or ANIM_NONE) then
			w.m_iAnim = a
		--end
		if DEBUG_STATES:GetBool() then
			DEBUG_I = DEBUG_I + 1
			print(DEBUG_I, p, DEF_STATE[s], DEF_ANIM[a], r and "RIPOSTE" or "")
		end
		if s == STATE_RECOVERY then
			timer.Simple(w.Windup, function()
				if p:IsValid() and not w.m_bRiposting and w.m_iState == STATE_RECOVERY then
					self:StateUpdate(p, STATE_IDLE, ANIM_NONE)
				end
			end)
		end

		--w:SetDTInt(WEP_STATE,s)
		--w:SetDTBool(0,r or false)
		--if a ~= nil and a ~= ANIM_SKIP then
			--w:SetDTInt(WEP_ANIM,a)
		--end

		local vm = p:GetViewModel()
		-- local lseq, ldur = defseq[s] ~= STATE_RECOVERY and vm:LookupSequence(defseq[s][a]) or vm:LookupSequence(defseq[s])
		if defseq[s] ~= STATE_RECOVERY then
			lseq, ldur = vm:LookupSequence(defseq[s][a])
		else
			lseq, ldur = vm:LookupSequence(defseq[s])
		end
		vm:SendViewModelMatchingSequence(lseq)
		-- Should move these calcs to client
		-- Thrust has terrible playback rate
		local calcwindup = r and w.Windup * w.RiposteMulti or w.Windup
		local prate = s ~= STATE_ATTACK and ldur / calcwindup or ldur / (w.Release * w.AngleStrike)
		vm:SetPlaybackRate(prate)
		
		net.Start("ms_state_update")
			net.WriteUInt(p:UserID(),16)
			net.WriteUInt(s,3)
			net.WriteUInt(a or ANIM_SKIP,3)
			net.WriteBool(r or false) -- bitset these maybe?
			net.WriteBool(f or false)
		net.Broadcast()
	end
end

function SWEP:EyeAnglesUpdate()
	if self:GetOwner() then
		net.Start("ms_ea_update")
		net.Send(self:GetOwner())
	end
end

function SWEP:AttackFinish(sv_tracers, tracerst, traceren, tracertag)
	
	local o = self:GetOwner()
	
	self.m_flPrevRecovery = CurTime() + self.Recovery
	
	self:StateUpdate(o, STATE_RECOVERY, self.m_iAnim, false, self.m_bFlip) -- ANIM_SKIP

	table.Empty(self.m_tFilter)
	self.m_bRiposting = false
	self:SetHoldType(self.IdleAnim)
	
	if DRAW_SV_TRACERS:GetBool() and sv_tracers then
		SV_TRACER_DRAW(tracerst, traceren,3, tracertag)
	end
end

function SWEP:Flinch(p)
	local w = p:GetActiveWeapon()
	if w.m_bRiposting then return end
	
	w.m_flPrevParry = 0.0
	w.m_flPrevFlinch = CurTime() + self.Recovery --+ self.AngleStrike * self.Release
	timer.Stop("ms_attack_" .. w:EntIndex())
	
	p:EmitSound("physics/flesh/flesh_strider_impact_bullet"..math.random(3)..".wav",75,120,1)
	self:StateUpdate(p, STATE_RECOVERY, ANIM_NONE)
	--[[
	-- CSENT flinch recovery anim
	if w.m_iState ~= STATE_IDLE then
		self:StateUpdate(p, STATE_RECOVERY)
		else
		self:StateUpdate(p, STATE_RECOVERY, ANIM_NONE)
	end
	]]
end

function SWEP:Riposte(p) -- successful parry
	p:EmitSound("physics/metal/metal_solid_impact_bullet"..math.random(2)..".wav",75,100,1)
	p:ViewPunch(Angle(-2,0,0))
	GAMEMODE:StaminaUpdate(p,p.m_iStamina - 7,true)
	
	local w = p:GetActiveWeapon()
	w.m_flPrevRecovery = 0.0
	w.m_flPrevParry = 0.0
	w.m_flPrevFlinch = 0.0
	
	timer.Create("ms_riposte_"..w:EntIndex(),1/6,1,function()
		if w.m_iQueuedAnim ~= ANIM_NONE then
			w.m_bRiposting = true
			w:m_fWindup(w.m_iQueuedAnim,true,w.m_bQueuedFlip)
		end
	end)
	
end

function SWEP:Parry()
	if CurTime() >= self.m_flPrevParry and self.m_iState <= STATE_RECOVERY then
	
		local o = self:GetOwner()
		self.m_flPrevParry = CurTime() + 1 + 1/3
		
		self.m_bRiposting = false
		self.m_bQueuedFlip = false
		self.m_iQueuedAnim = ANIM_NONE
		
		if self.m_iState == STATE_IDLE or STATE_WINDUP then
			
			o:EmitSound("physics/flesh/flesh_impact_hard3.wav", 75, 100, 1)
			self:SetHoldType(self.ParryAnim)
			
			if self.m_iState == STATE_WINDUP then
				GAMEMODE:StaminaUpdate(o, o.m_iStamina - self.FeintDrain, true) -- FTP punish
			elseif self.m_iState == STATE_IDLE then
				GAMEMODE:StaminaUpdate(o, nil, true)
			end
			
			timer.Stop("ms_attack_"..self:EntIndex())
			self:StateUpdate(o, STATE_PARRY, ANIM_NONE)
			self:EyeAnglesUpdate()
			
			timer.Simple(1/3, function()
				if self.m_iState == STATE_WINDUP and self.m_flPrevRecovery == 0.0 then return end
				if not self.m_bRiposting then
					self:StateUpdate(o, STATE_RECOVERY, ANIM_NONE)
				end
				
				self:SetHoldType(self.IdleAnim)
				o:EmitSound("physics/flesh/flesh_impact_hard2.wav",75,50,1)
			end)
		
		end
	end
end

function SWEP:Feint()
	if self.m_iState == STATE_WINDUP and not self.m_bRiposting and self:GetOwner().m_iStamina ~= 0 then
		local o = self:GetOwner()
		self:StateUpdate(o, STATE_IDLE, ANIM_NONE)
		timer.Stop("ms_attack_" .. self:EntIndex())
		GAMEMODE:StaminaUpdate(o, o.m_iStamina - self.FeintDrain, true)
	end
end