-- Deprecated code

CALC_SLASH = {
	[ANIM_NONE] = {nil, nil},
	[ANIM_STRIKE] = {-1, 90},
	[ANIM_UPPERCUT] = {-1, 45},
	[ANIM_UNDERCUT] = {1, -45},
	[ANIM_THRUST] = {nil, nil}
}

ENABLE_CSENT = CreateConVar("ms_cl_enable_csent", "0", true, false)

hook.Add("PostPlayerDraw", "ms_Playermodels", function(p) 
	if IsValid(p:GetActiveWeapon()) then
        if not p.m_iRHand then
            p.m_flPrevAng = 0.0
            p.m_iRUpperarm = p:LookupBone("ValveBiped.Bip01_R_UpperArm")
            p.m_iRForearm = p:LookupBone("ValveBiped.Bip01_R_Forearm")
            p.m_iRHand = p:LookupBone("ValveBiped.Bip01_R_Hand")
        end

		local w = p:GetActiveWeapon()
		local ea = p:EyeAngles()

		-- Inverts poseparams and texture normals because pmodel gets enablematrix'd with a negative value
		p.RenderOverride = function(self)
			if w.m_iFlip ~= 1 then
				render.CullMode(MATERIAL_CULLMODE_CW)
				for _, v in ipairs({"aim_yaw", "move_y"}) do
					local min, max = self:GetPoseParameterRange(self:LookupPoseParameter(v))
					self:SetPoseParameter(v, min+max - math.Remap(self:GetPoseParameter(v), 0, 1, min, max))
				end
				self:DrawModel()
				render.CullMode(MATERIAL_CULLMODE_CCW)
			else
				self:DrawModel()
			end
		end

		if w.m_iState == STATE_IDLE then
			if not p:GetManipulateBoneAngles(p.m_iRHand):__eq(Angle()) then -- rhand is always changed
				local flFraction = 1 - math.ease.OutCubic(math.Clamp((CurTime()-w.m_flPrevState)/w.Recovery, 0, 1))
				p:ManipulateBoneAngles(p.m_iRHand, p.m_aRHand:__mul(flFraction))
				p:ManipulateBoneAngles(p.m_iRForearm, p.m_aRForearm:__mul(flFraction))
				p:ManipulateBoneAngles(p.m_iRUpperarm, p.m_aRUpperarm:__mul(flFraction))
			end
		elseif w.m_iState == STATE_PARRY then -- Do nothing, we change aimlayer instead
		elseif w.m_iState == STATE_WINDUP then -- Only attack anims can be here
				local multi = w.m_bRiposting and w.RiposteMulti or 1
				local flAng = math.Clamp(90/((w.Windup*multi)/(CurTime()-w.m_flPrevState)), 0, 90)
			if w.m_iAnim == ANIM_STRIKE then
				p:ManipulateBoneAngles(p.m_iRHand, Angle(-flAng, 0, 0))
				p:ManipulateBoneAngles(p.m_iRForearm, Angle(0, flAng, 0))
				p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(0, flAng, 0))
			elseif w.m_iAnim == ANIM_UPPERCUT then
				p:ManipulateBoneAngles(p.m_iRHand, Angle(0, -flAng, flAng))
				p:ManipulateBoneAngles(p.m_iRForearm, Angle(0, flAng, 0))
				p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(flAng, 0, 0))
			elseif w.m_iAnim == ANIM_UNDERCUT then
				p:ManipulateBoneAngles(p.m_iRHand, Angle(0, -flAng, flAng))
				p:ManipulateBoneAngles(p.m_iRForearm, Angle(0, flAng, 0))
			elseif w.m_iAnim == ANIM_THRUST then
				p:ManipulateBoneAngles(p.m_iRHand, Angle(0, 0, -flAng/2))
				p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(0, flAng, 0))
			end
		elseif w.m_iState == STATE_RECOVERY then
			local flFraction = 1 - math.ease.InCubic(math.Clamp((CurTime()-w.m_flPrevState)/w.Recovery, 0, 1))
			p:ManipulateBoneAngles(p.m_iRHand, p.m_aRHand:__mul(flFraction))
			p:ManipulateBoneAngles(p.m_iRForearm, p.m_aRForearm:__mul(flFraction))
			p:ManipulateBoneAngles(p.m_iRUpperarm, p.m_aRUpperarm:__mul(flFraction))
		elseif w.m_iState == STATE_ATTACK then
			local flAng = 0.0
			if w.m_iAnim == ANIM_STRIKE then -- Only attack anims can be here
				flAng = math.Clamp((CurTime()-w.m_flPrevState)/w.Release, 0, w.AngleStrike)
				p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(60*math.sin(math.rad(flAng*(4/3))), 90-flAng*(4/3)+30), flAng*0.4)
			elseif w.m_iAnim == ANIM_UPPERCUT then
				flAng = math.Clamp((CurTime()-w.m_flPrevState)/w.Release, 0, w.AngleStrike)
				p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(90+flAng, 90-30*flAng/w.AngleStrike, 120))
			elseif w.m_iAnim == ANIM_UNDERCUT then
				flAng = math.Clamp((CurTime()-w.m_flPrevState)/w.Release, 0, w.AngleStrike)
				p:ManipulateBoneAngles(p.m_iRUpperarm, Angle(-30*flAng/w.AngleStrike, -flAng, 0))
			elseif w.m_iAnim == ANIM_THRUST then
				flAng = CurTime()-w.m_flPrevState
				local pace_90 = math.Clamp(flAng/w.Release, 0, 90) -- a thrust will always have only 90 iterations(?)
				p:ManipulateBoneAngles(p.m_iRHand,Angle(-100*pace_90/90, -15*pace_90/90, -90+pace_90))
				p:ManipulateBoneAngles(p.m_iRForearm,Angle(0, pace_90, 0))
				p:ManipulateBoneAngles(p.m_iRUpperarm,Angle(0, 90-180*pace_90/90, 0))
			end
			p.m_flPrevAng = flAng
		end
	end
end)

do
	local recovery_flAng, fpos, fang
	hook.Add("CalcViewModelView","ms_VModelLuaAnim", function() 
		if IsValid(LocalPlayer():GetActiveWeapon()) and LocalPlayer().CSENT then
			local p = LocalPlayer()
			local w = p:GetActiveWeapon()
			local ea = p:EyeAngles()
			local ep = p:EyePos()
			local flip = w.m_iFlip
			local P_CSENT = LocalPlayer().CSENT

			if w.m_iState == STATE_IDLE then
				fpos = ep+ea:Forward()*16+ea:Right()*8
				fang = Angle(ea[1]+90, ea[2], 0)
			elseif w.m_iState == STATE_PARRY then
				fpos = ep+ea:Forward()*16
				fang = Angle(ea[1], ea[2]-90, 0)
			elseif w.m_iState == STATE_WINDUP then
				local multi = w.m_bRiposting and w.RiposteMulti or 1
				local flAng = (CurTime()-w.m_flPrevState)/(w.Windup*multi)
				if w.m_iAnim == ANIM_STRIKE then
					fpos = ep+ea:Forward()*(8-16*flAng)+ea:Right()*8*flip+ea:Up()*-8
					fang = Angle(ea[1], ea[2]+15*flip, 90)
				elseif w.m_iAnim == ANIM_UPPERCUT then
					fpos = ep+ea:Forward()*16+ea:Right()*(8*flip+16*flAng*flip)+ea:Up()*(16*flAng)
					fang = Angle(ea[1]+45, ea[2], 0)
				elseif w.m_iAnim == ANIM_UNDERCUT then
					fpos = ep+ea:Forward()*(8-16*flAng)+ea:Right()*8*flip+ea:Up()*(-8-16*flAng)
					fang = Angle(ea[1]-45, ea[2], 90)
				elseif w.m_iAnim == ANIM_THRUST then
					fpos = ep+ea:Forward()*(16-8*flAng)+ea:Up()*-8+ea:Right()*8*flip
					fang = Angle(ea[1]-180, ea[2], 0)
				end
			elseif w.m_iState == STATE_RECOVERY then
				local flAng = 16*(CurTime()-w.m_flPrevState) / w.Recovery
				local recovery_st, recovery_en
				if w.m_iAnim ~= ANIM_THRUST and w.m_iAnim ~= ANIM_NONE then -- Slash attacks
					local inv, rot = unpack(CALC_SLASH[w.m_iAnim]) -- Might be expensive?
					local normal = Angle(w.AngleStrikeOffset*inv - ea[1] + recovery_flAng*inv, 180+ea[2], 0)
					normal:RotateAroundAxis(ea:Forward(), rot*flip)
					recovery_st = ep + normal:Forward() * (32 - flAng) + normal:Right() * 8*inv*flip
					recovery_en = ep + normal:Forward() * (32 + w.Range) + normal:Right() * 8*inv*flip
					fpos = recovery_st
					fang = (recovery_st - recovery_en):Angle()
				elseif w.m_iAnim == ANIM_THRUST then
					local normal = Angle(Angle(ea[1] + math.cos(math.rad(270*recovery_flAng/90)) * 2, ea[2] - math.sin(math.rad(270*recovery_flAng/90)) * 2*flip, 0))
					recovery_st = ep + normal:Forward() * ((32+6*(recovery_flAng/90))-flAng) + normal:Up() * -8 + normal:Right() * 8*flip
					recovery_en = ep + normal:Forward() * ((32 + w.Range)+6*(recovery_flAng/90)) + normal:Up() * -8 + normal:Right() *8*flip
					fpos = recovery_st
					fang = (recovery_st - recovery_en):Angle()
				elseif w.m_iAnim == ANIM_NONE then
					fpos = ep+ea:Forward()*16+ea:Right()*8
					fang = Angle(ea[1]+90, ea[2], 0)
				end
			elseif w.m_iState == STATE_ATTACK then
				local flAng = (CurTime()-w.m_flPrevState) / w.Release
				local st, en
				if w.m_iAnim ~= ANIM_THRUST then
					local inv, rot = unpack(CALC_SLASH[w.m_iAnim]) -- Might be expensive?
					local normal = Angle(w.AngleStrikeOffset*inv - ea[1] + flAng*inv, 180+ea[2], 0)
					normal:RotateAroundAxis(ea:Forward(), rot*flip)
					st = ep + normal:Forward() * 32 + normal:Right() * 8*inv*flip
					en = ep + normal:Forward() * (32 + w.Range) + normal:Right() * 8*inv*flip
				else
					local normal = Angle(Angle(ea[1] + math.sin(math.rad(270/(90/flAng)+90)) * 2, ea[2] - math.sin(math.rad(270/(90/flAng))) * 2*flip, 0))
					st = ep + normal:Forward() * (32+12*(1/(90/flAng))) + normal:Up() * -8 + normal:Right() * 8 * flip
					en = ep + normal:Forward() * ((32 + w.Range)+12*(1/(90/flAng))) + normal:Up() * -8 + normal:Right() * 8 * flip
				end
				if CL_DRAW_TRACERS:GetBool() then
					CL_TRACER_DRAW(st, en)
				end
				recovery_flAng = flAng -- Both
				fpos = st
				fang = (st - en):Angle()
			end
			if ENABLE_CSENT:GetBool() then -- Should also affect everything but state_attack, this is temporary
				P_CSENT:SetPos(fpos)
				P_CSENT:SetAngles(fang)
			end
		end
	end)
end

local iAngleFinal = self.m_iAnim ~= ANIM_THRUST and self.AngleStrike or 90
-- Reminder, unpack must be the last arg, this is lua's defined behavior (for functions of course)
local inv, rot = unpack(CALC_SLASH[self.m_iAnim])
for iAng = 0, iAngleFinal do
	timer.Simple(self.Release * iAng, function()
		if o:IsValid() and self.m_iState == STATE_ATTACK then
			local ea = o:EyeAngles()
			local ep = o:EyePos()
			local st, en
			if self.m_iAnim ~= ANIM_THRUST then
				local normal = Angle(self.AngleStrikeOffset*inv - ea[1] + iAng*inv, 180+ea[2], 0)
				normal:RotateAroundAxis(ea:Forward(), rot*flip)
				st = ep + normal:Forward() * 32 + normal:Right() * 8*inv*flip -- Right is UP(?)
				en = ep + normal:Forward() * (32 + self.Range) + normal:Right() * 8*inv*flip
			else
				local normal = Angle(Angle(ea[1] + math.cos(math.rad(270*iAng/iAngleFinal)) * 2, ea[2] - math.sin(math.rad(270*iAng/iAngleFinal)) * 2*flip, 0))
				st = ep + normal:Forward() * (32+6*(iAng/iAngleFinal)) + normal:Up() * -8 + normal:Right() * 8*flip
				en = ep + normal:Forward() * ((32 + self.Range)+6*(iAng/iAngleFinal)) + normal:Up() * -8 + normal:Right() * 8*flip
			end
			o:LagCompensation(true)
			local tr = util.TraceLine({
				start = st,
				endpos = en,
				filter = self.m_tFilter
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
								GAMEMODE:StaminaUpdate(o, o.m_iStamina + 40, true)
								self:DamageSimple(iAng, tr.Entity, CheckMulti(tr.Entity,tr.HitGroup))
								
								self.m_tFilter[#self.m_tFilter + 1] = tr.Entity
							end
						else
							self:Flinch(tr.Entity)
							GAMEMODE:StaminaUpdate(o, o.m_iStamina + 40, true)
							self:DamageSimple(iAng, tr.Entity, CheckMulti(tr.Entity,tr.HitGroup))
							self:AttackFinish(true, st, en, self.slashtag)
							return
						end
					end
						
				elseif tr.Entity:GetClass() == ("prop_physics" or "prop_physics_multiplayer" or "func_physbox") and tr.Entity:GetPhysicsObject() then
					tr.Entity:GetPhysicsObject():SetVelocity(tr.Entity:GetVelocity() + (tr.Entity:GetPos()-tr.HitPos)*1000)
					tr.Entity:EmitSound("physics/metal/metal_barrel_impact_hard"..math.random(3)..".wav", 75, 120, 1)
					self:DamageSimple(iAng, tr.Entity, 1)
					self:AttackFinish(true, st, en, self.slashtag)
					GAMEMODE:StaminaUpdate(o, o.m_iStamina - self.StaminaDrain, true)
					return
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
			
			
			if iAng == iAngleFinal then
				self:AttackFinish(false)
				GAMEMODE:StaminaUpdate(o,o.m_iStamina - self.StaminaDrain,true)
				return
			end
		end
	end)
end

-- Used for slash calculations, constants
CALC_SLASH = {
	[ANIM_NONE] = {nil, nil},
	[ANIM_STRIKE] = {-1, 90},
	[ANIM_UPPERCUT] = {-1, 45},
	[ANIM_UNDERCUT] = {1, -45},
	[ANIM_THRUST] = {nil, nil}
}