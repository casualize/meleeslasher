INC_CLIENT()

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Int", 1, "Anim")
	self:NetworkVar("Bool", 0, "Riposte")
	self:NetworkVar("Bool", 1, "Flip")

	self:NetworkVar("Bool", 2, "Success") -- For cl anim

	self:NetworkVarNotify("State", function(ent, name, old, new)
		self.m_iPrevState = old
		self.m_iState = new
		self.m_flPrevState = CurTime()
		self:AnimInit()
	end)
	self:NetworkVarNotify("Anim", function(ent, name, old, new)
		self.m_iAnim = new
		self.m_iQueuedAnim = self:GetOwner() == LocalPlayer() and new
	end)
	self:NetworkVarNotify("Riposte", function(ent, name, old, new)
		self.m_bRiposting = new
	end)
	self:NetworkVarNotify("Flip", function(ent, name, old, new)
		self.m_bFlip = new
		self.m_bQueuedFlip = self:GetOwner() == LocalPlayer() and new
	end)
	self:NetworkVarNotify("Success", function(ent, name, old, new)
		self.m_flPrevParry = 0.0
	end)
end

-- This is still a callback for both lplayer and pl
function SWEP:AnimInit()
	local o = self:GetOwner()
	o:AnimResetGestureSlot(GESTURE_SLOT_VCD) -- Emotes
	if o == LocalPlayer() then
		self.viewangles = LocalPlayer():EyeAngles()
	end 

	-- For some reason anything but lp doesn't get set to ANIM_NONE when STATE_PARRY? this is a hotfix.
	if self.m_iState == STATE_PARRY then
		self.m_iAnim = ANIM_NONE
	end

	if o ~= LocalPlayer() then
		if self.m_iState and self.m_iAnim then -- ?
			local seq = DEF_ANM_SEQUENCES[self.m_iState][self.m_iAnim]
			if seq ~= nil then
				if seq == "ms_parry" then -- Must be seperate boolean logic (hotfix)
					o:AddVCDSequenceToGestureSlot(1, o:LookupSequence(seq), 0, true)
				end
			else
				o:AnimResetGestureSlot(0)
			end
			if self.m_iState == STATE_WINDUP then
				o:AnimRestartGesture(GESTURE_SLOT_JUMP, ACT_FLINCH_SHOULDER_RIGHT, true)
			end
		end
	end
end

-- Anything else below is for localplayer, stuff that happens without sv permission

function SWEP:Queue(a_state, flip)
	self.m_iQueuedAnim = a_state
	self.m_bQueuedFlip = flip
	if ((self.m_iState == STATE_IDLE --[[and self.m_flPrevState + self.Recovery <= CurTime()]]) or self.m_iState == STATE_PARRY) and not self.m_bRiposting then
		net.Start("ms_anim_queue")
			net.WriteUInt(a_state, 3)
			net.WriteBool(flip)
		net.SendToServer()
	end

	if self.m_iState == STATE_IDLE and self.m_flPrevState + self.Recovery <= CurTime() then
		local p = LocalPlayer()
		self:StateUpdate(p, STATE_WINDUP, a_state, self.m_bRiposting, flip)
		self.viewangles = p:EyeAngles()
	end
end

function SWEP:StateUpdate(p, s, a, r, f)
	local w = p:GetActiveWeapon()
	if IsValid(w) then
		self.viewangles = LocalPlayer():EyeAngles() -- Turncap update
		local seq = DEF_ANM_SEQUENCES[s][a]
		if seq ~= nil then
			if seq == "ms_parry" then
				p:AddVCDSequenceToGestureSlot(1, p:LookupSequence(seq), 0, true)
			end
		else
			p:AnimResetGestureSlot(0)
		end

		w.m_iState = s or w.m_iState
		w.m_iAnim = a or w.m_iAnim
		w.m_bFlip = (f) or w.m_bFlip -- Sometimes changes to nil? Mandatory fallback
	end
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	self:Queue(ANIM_STRIKE, self.m_bMVDATA)
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end
	self:Parry()
end

function SWEP:Parry()
	local p = LocalPlayer()
	if CurTime() >= self.m_flPrevParry and (self.m_iState == STATE_IDLE or 
	(self.m_iState == STATE_WINDUP --[[and CurTime() <= self.m_flPrevState + self.Windup ]]))
	then

		-- Reset fields
		self.m_bRiposting = false
		self.m_bQueuedFlip = false
		self.m_iQueuedAnim = ANIM_NONE
		
		self.m_flPrevParry = CurTime() + 1 + 1/3
		
		if self.m_iState == STATE_IDLE or STATE_WINDUP then
			self:StateUpdate(p, STATE_PARRY, ANIM_NONE)
		end
	end
end

do
	local function add_quad(start_pos, stop_pos, start_ang, stop_ang, start_width, stop_width, r,g,b,a)
		local lower_right = Vector(0,-start_width*0.5,0)
		local lower_left = Vector(0,start_width*0.5,0)

		local upper_right = Vector(0,-stop_width*0.5,0)
		local upper_left = Vector(0,stop_width*0.5,0)

		lower_right:Rotate(start_ang)
		upper_right:Rotate(stop_ang)

		lower_left:Rotate(start_ang)
		upper_left:Rotate(stop_ang)

		mesh.TexCoord(0, 0, 1)
		mesh.Color(r,g,b,a)
		mesh.Position(stop_pos + upper_left)
		mesh.AdvanceVertex()

		mesh.TexCoord(0, 0, 0)
		mesh.Color(r,g,b,a)
		mesh.Position(start_pos + lower_left)
		mesh.AdvanceVertex()

		mesh.TexCoord(0, 1, 0)
		mesh.Color(r,g,b,a)
		mesh.Position(start_pos + lower_right)
		mesh.AdvanceVertex()

		mesh.TexCoord(0, 1, 1)
		mesh.Color(r,g,b,a)
		mesh.Position(stop_pos + upper_right)
		mesh.AdvanceVertex()

		mesh.TexCoord(0, 0, 1)
		mesh.Color(r,g,b,a)
		mesh.Position(stop_pos + upper_left)
		mesh.AdvanceVertex()

		mesh.TexCoord(0, 1, 0)
		mesh.Color(r,g,b,a)
		mesh.Position(start_pos + lower_right)
		mesh.AdvanceVertex()
	end
	local mat = CreateMaterial( "ms_trail", "UnlitGeneric", {
		["$basetexture"] = "trail/gradient",
		["$nocull"] = 1,
		["$additive"] = 1,
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1
	  } )
	function SWEP:DrawWorldModel()
		local o = self:GetOwner()
		self:DrawModel(1)
		for i = 0, o:GetBoneCount() - 1 do
			self.m_iAttachID = o:GetBoneName(i) -- Temporarily set it to a string
			if self.m_iAttachID == "ValveBiped.Anim_Attachment_RH" then
				self.m_iAttachID = i
				break
			end
		end

		if type(self.m_iAttachID) == "string" then return end -- Bandaid fix for error spam 

		local bm = o:GetBoneMatrix(self.m_iAttachID) -- The returns are fixed on tick...
		local v = bm:GetTranslation()
		local a = bm:GetAngles()


		--a:RotateAroundAxis(a:Right(), 0)
		if not self.m_tPos[1] or self.m_tPos[1].v:Distance(v) > 1 and self.m_iState == STATE_ATTACK then
			table.insert(self.m_tPos, {v = v + a:Right() * -self.Range*(3/4), a = a})
		end

		if #self.m_tPos > 64 or self.m_iState ~= STATE_ATTACK then
			table.remove(self.m_tPos, 1)
		end

		render.SetMaterial(mat)

		local quads = #self.m_tPos
		render.SuppressEngineLighting(true)
		mesh.Begin(MATERIAL_TRIANGLES, 2*quads)
			local ok, err = pcall(function()
			for i = 0, quads - 1 do
				local a = self.m_tPos[i+1]
				local b = self.m_tPos[i]
				if a and b then
					add_quad(b.v, a.v, b.a, a.a, self.Range, self.Range, 192, 192, 192, 55*(i/quads)^1)
				end
			end
			end) if not ok then ErrorNoHalt(err) end
		mesh.End()
		render.SuppressEngineLighting(false)
	end
end