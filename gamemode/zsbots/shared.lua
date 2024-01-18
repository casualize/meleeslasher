-- unobstructed path has a flaw where people in the air are considered a straight path (on ground check?)

ZSBOTS = {}
REF_ZSBOTS = {} -- Sequential

local RealTime = RealTime
local CurTime = CurTime
local IN_ATTACK = IN_ATTACK
local IN_JUMP = IN_JUMP
local IN_DUCK = IN_DUCK
local IN_FORWARD = IN_FORWARD
local IN_MOVELEFT = IN_MOVELEFT
local IN_MOVERIGHT = IN_MOVERIGHT
local util_TraceEntity = util.TraceEntity
local Path = Path

local eyepos, target
local obstrace = {mask = MASK_PLAYERSOLID, filter = function(ent) return ent ~= target and not ent:IsPlayer() end}
function ZSBOTS.StartCommand(pl, cmd)
	if not pl.m_bZSBot or not pl:Alive() then return end

	local buttons = 0

	if pl.HoldDuckUntil then
		if CurTime() > pl.HoldDuckUntil then
			pl.HoldDuckUntil = nil
		else
			buttons = bit.bor(buttons, IN_DUCK)
		end
	end

	if pl.ShouldJump then
		pl.ShouldJump = false

		buttons = bit.bor(buttons, IN_JUMP)

		pl.HoldDuckUntil = CurTime() + 1
	end

	local mypos = pl:GetPos()
	eyepos = pl:EyePos()

	target = pl.CurrentEnemy
	local destination = pl.MovementTarget
	local targetpos
	local targetdist
	local targetunobstructed

	if target:IsValid() then
		if not destination then
			destination = target:GetPos()
		end
		targetpos = (target:WorldSpaceCenter() * 2 + target:NearestPoint(eyepos)) / 3
		targetdist = targetpos:DistToSqr(eyepos)

		--if target:VisibleVec(eyepos) then
			obstrace.start = pl:GetPos():__add(Vector(0,0,1))
			obstrace.endpos = target:WorldSpaceCenter()
			if not util_TraceEntity(obstrace, pl).Hit then
				targetunobstructed = true
			end
		--end
	end

	local viewang

	if destination then
		local wep = pl:GetActiveWeapon()
		local twep = target:GetActiveWeapon()
		local targetstate = twep.m_iState
		local targetriposte = twep.m_bRiposting
		if targetunobstructed then
			if targetdist < 5000 then
				-- Check if we're "inside" the target or they're on top of us, we're on top of them.
				local eyepos2d = Vector() eyepos2d:Set(eyepos) eyepos2d.z = 0
				local targetpos2d = Vector() targetpos2d:Set(targetpos) targetpos2d.z = 0
				if eyepos2d:DistToSqr(targetpos2d) < 2000 then
					buttons = bit.bor(buttons, IN_BACK)
					cmd:SetForwardMove(-10000)

					viewang = pl:EyeAngles()
					viewang.pitch = eyepos.z < targetpos.z and -60 or viewang.pitch
					--[[
					if eyepos.z < targetpos.z then
						-- They're on top of us.
						viewang.pitch = -60
					else
						-- We're on top of them.
						viewang.pitch = 89 -- false assumption(?)
						buttons = bit.bor(buttons, IN_DUCK)
					end
					]]
				else
					-- No but we're very close, so start doing anti-juke measures.
					buttons = bit.bor(buttons, IN_FORWARD)
					cmd:SetForwardMove(10000)

					viewang = (targetpos - eyepos):Angle()
					viewang.roll = 0

					local target_vel2d = target:GetVelocity()
					target_vel2d.z = 0
					targetpos = targetpos + --[[FrameTime() * 2 *]] target_vel2d * 1.5
				end
			else
				viewang = (destination - mypos):Angle()
				viewang.pitch = 0
				viewang.roll = 0
				buttons = bit.bor(buttons, IN_SPEED)
				if destination:DistToSqr(mypos) > 256 then
					buttons = bit.bor(buttons, IN_FORWARD)
					cmd:SetForwardMove(10000)
				end
			end

			local strafe_randomness = (CurTime() + pl:EntIndex() * 0.2) % 1 + math.Rand(0, 1)
			if strafe_randomness < 0.5 then
				buttons = bit.bor(buttons, IN_MOVELEFT)
				cmd:SetSideMove(-10000)
			elseif strafe_randomness > 1.5 then
				buttons = bit.bor(buttons, IN_MOVERIGHT)
				cmd:SetSideMove(10000)
			end
		else
			viewang = (destination - mypos):Angle()
			viewang.pitch = 0
			viewang.roll = 0

			if destination:DistToSqr(mypos) > 256 then
				buttons = bit.bor(buttons, IN_FORWARD)
				cmd:SetForwardMove(10000)
			end
		end

		local meleerange = 128*128
		if targetdist then
			if targetdist <= meleerange then
				if (targetstate == STATE_IDLE or targetstate == STATE_WINDUP)  then
					-- Feel free to replace the Angle functions for spastic bot behaviour
					if wep.m_iState == STATE_IDLE then
						pl.m_aAttack = Angle() -- Angle(math.random(-30,30),math.random(-30,30),0)
						wep.m_iQueuedAnim = math.random(2, 5)
						wep.m_bQueuedFlip = math.random() >= 0.5
					end
					if wep.m_iState == STATE_WINDUP then
						viewang = (destination - mypos):Angle():__add(pl.m_aAttack)
						if pl.m_flDebugNext + 0.1 <= CurTime() then
							pl.m_flDebugNext = CurTime()
							pl.m_aAttack = Angle() -- Angle(math.random(-30,30),math.random(-30,30),0)
						end
						if pl.m_flNextFeint <= CurTime() then
							pl.m_flNextFeint = CurTime() + math.Rand(2, 6)
							wep:Feint()
						end
					end
				elseif targetstate == STATE_ATTACK then
					buttons = bit.bor(buttons, IN_BACK)
					cmd:SetForwardMove(-10000)
					wep:Feint()
					wep:Parry()
				end
				if targetriposte then
					buttons = bit.bor(buttons, IN_BACK)
					cmd:SetForwardMove(-10000)
				end
				if wep.m_iState == STATE_PARRY then
					wep.m_iQueuedAnim = math.random(2, 5)
					wep.m_bQueuedFlip = math.random() >= 0.5 
				elseif wep.m_iState == STATE_ATTACK then
					buttons = bit.bor(buttons, IN_FORWARD)
					cmd:SetForwardMove(10000)
					if wep.m_iAnim ~= ANIM_THRUST and wep.m_iAnim ~= ANIM_STRIKE then
						viewang = (destination - mypos):Angle():__add(pl.m_aAttack)
					elseif wep.m_iAnim == ANIM_STRIKE then
						viewang = (destination - mypos):Angle():__add(Angle(0,pl.m_aAttack[2],0))
					end
				end
			end
		end

		if CurTime() <= pl.UnStuckTime then
			if CurTime() % 2 < 0.5 then
				buttons = bit.bor(buttons, IN_MOVELEFT)
				cmd:SetSideMove(-10000)
			else
				buttons = bit.bor(buttons, IN_MOVERIGHT)
				cmd:SetSideMove(10000)
			end

			buttons = bit.bor(buttons, IN_ATTACK)
		end
	end

	if viewang then
		cmd:SetViewAngles(viewang)
		pl:SetEyeAngles(viewang)
	end

	cmd:SetButtons(buttons)
end

function ZSBOTS.PlayerTick(pl, mv)
	if not pl.m_bZSBot then return end

	pl.NB:SetPos(pl:GetPos():__add(Vector(0,0,8)))
	pl.NB:SetLocalVelocity(vector_origin)

	if not pl:Alive() then return end

		-- We don't update our path every frame because it would be excessive.
		-- We move directly towards a player if we're very near and visible so that's okay.
		if CurTime() >= pl.NextPathUpdate then
			pl.NextPathUpdate = CurTime() + 0.1
			pl:UpdateBotPath()
		end

		if CurTime() > pl.UnStuckTime and mv:GetVelocity():Length2DSqr() < 4096 then
			pl.StuckFrames = pl.StuckFrames + 1
			if pl.StuckFrames >= 10 then
				pl.UnStuckTime = CurTime() + 1
				pl.StuckFrames = 0
			end
		else
			pl.StuckFrames = 0
		end
end

local temp_bot_pos
local function SortPathableTargets(enta, entb)
	local dista = enta:GetPos():DistToSqr(temp_bot_pos)
	dista = dista + enta._temp_bot_dist_add
	dista = dista * enta._temp_bot_dist_mul
	local distb = entb:GetPos():DistToSqr(temp_bot_pos)
	distb = distb + entb._temp_bot_dist_add
	distb = distb * entb._temp_bot_dist_mul

	return dista < distb
end

local NextBotTick = 0
function ZSBOTS.Think()
	for _, bot in ipairs(REF_ZSBOTS) do
		if bot ~= NULL and not bot:Alive() then
			gamemode.Call("PlayerDeathThink", bot)
		end
	end

	if CurTime() < NextBotTick then return end
	NextBotTick = CurTime() + 0.25

	-- This is significantly cheaper than pathfinding to all valid targets.
	for _, bot in ipairs(REF_ZSBOTS) do
		bot.PathableTargets = {}

		for __, pl in ipairs(player.GetAll()) do
			if pl:Team() ~= bot:Team() and  pl:Alive() and pl:GetObserverMode() == OBS_MODE_NONE then
				table.insert(bot.PathableTargets, pl)
			elseif pl:IsBot() and not pl:Alive() then
				gamemode.Call("PlayerDeathThink", pl)
			end
		end
		
		temp_bot_pos = bot:GetPos()
		obstrace.start = temp_bot_pos:__add(Vector(0,0,1))

		local dist_add, dist_mul
		for __, target in ipairs(bot.PathableTargets) do
			obstrace.endpos = target:WorldSpaceCenter()

			dist_add = 0
			dist_mul = 1

			-- Favor people with low health
			if target:IsPlayer() then
				if target:Health() < 50 then dist_add = dist_add - 75 end

				-- Greatly favor people that are visible
				obstrace.endpos = target:WorldSpaceCenter()
				if not util_TraceEntity(obstrace, bot).Hit then
					dist_mul = dist_mul / 2
				end

				-- Favor current enemy
				if target == bot.CurrentEnemy then dist_add = dist_add - 50 end
			else
				-- Unfavor non-players
				dist_add = dist_add + 128
			end

			target._temp_bot_dist_add = dist_add
			target._temp_bot_dist_mul = dist_mul
		end

		table.sort(bot.PathableTargets, SortPathableTargets)
	end
end

function ZSBOTS:CreateBot(teamid, name)
	if game.SinglePlayer() then return end

	if not navmesh.IsLoaded() then
		print("No navmesh - can't create bot. Try ms_createnavmesh")
		return
	end

	-- Might conflict with connecting players?
	name = name ~= nil and name or ("UserID " .. player.GetAll()[player.GetCount()]:UserID() + 1)

	ZSBOT = true

	local pl = player.CreateNextBot(name)
	if pl:IsValid() then
		pl.m_bZSBot = true

		pl:SetTeam(teamid)
		pl:Spawn()

		local nb = ents.Create("zsbotnb")
		nb:SetPos(pl:GetPos())
		nb:SetNoDraw(true)
		nb:Spawn()
		nb:SetOwner(pl)
		pl:DeleteOnRemove(nb)
		pl.NB = nb
		nb.PL = pl

		pl.m_flNextFeint = 0.0
		pl.m_flDebugNext = 0.0
		pl.m_aAttack = Angle()
		
		pl.CurrentEnemy = NULL
		pl.TargetAcquireTime = 0
		pl.StuckFrames = 0
		pl.UnStuckTime = 0
		pl.NextPathUpdate = 0
		pl.PathableTargets = {}

		table.insert(REF_ZSBOTS, pl)

		self:AddOrRemoveHooks()
	end

	ZSBOT = false
end

do
	local randomtaunts = {
		"dang owned :remnic:",
		"woooooow killed by a bot",
		":ez:",
		"fucking owned lol :ez::gg:",
		":dsp drot=-90 rotrate=60::gunl drot=25 rotrate=130::ahhahahaha c=255,0,0::youdied:"
	}
	function ZSBOTS.DoPlayerDeath(p, att, info)
		if att.m_bZSBot and not p:IsBot() then
			-- att:Say(table.Random(randomtaunts))
		end
	end
end

function ZSBOTS.PlayerDisconnected(p)
	if p:IsBot() and p.m_bZSBot then
		table.RemoveByValue(REF_ZSBOTS, p)
		ZSBOTS:AddOrRemoveHooks()
	end
end

-- Recalling hook.add will override the function() ? This may cause issues
function ZSBOTS:AddOrRemoveHooks()
	for _, v in ipairs({"StartCommand", "Think", "PlayerTick", "DoPlayerDeath", "PlayerDisconnected"}) do
		hook[#REF_ZSBOTS ~= 0 and "Add" or "Remove"](v, "ZSBOTS_" .. v, self[v]) -- Last arg is only for "Add"
	end
end

local meta = FindMetaTable("Player")
function meta:SetCurrentEnemy(enemy)
	enemy = (not enemy or not enemy:IsValid()) and NULL or enemy

	if self.CurrentEnemy ~= enemy then
		local old_enemy = self.CurrentEnemy
		self.CurrentEnemy = enemy
		self:EnemyChanged(old_enemy)
	end
end

function meta:SetMovementTarget(vec)
	self.MovementTarget = vec
end

function meta:ClearMovementTarget()
	self:SetMovementTarget(nil)
end

local loco, compute_step_height
local function Compute(area, fromArea, ladder, elevator, length)
	-- first area in path, no cost
	if not fromArea or not fromArea:IsValid() then
		return 0
	end

	-- our locomotor says we can't move here
	--[[if not loco:IsAreaTraversable(area) then
		return -1
	end]]

	if area:HasAttributes(NAV_MESH_INVALID) then return -1 end
	if area:HasAttributes(NAV_MESH_AVOID) then return -1 end

	if not area:IsVisible(fromArea:GetClosestPointOnArea(area:GetCenter())) then
		return -1
	end

	-- compute distance traveled along path so far
	local dist = 0

	if ladder and ladder:IsValid() then
		dist = ladder:GetLength()
	elseif length > 0 then
		dist = length -- optimization to avoid recomputing length
	else
		dist = (area:GetCenter() - fromArea:GetCenter()):Length()
	end

	local cost = dist + fromArea:GetCostSoFar()

	--[[if not fromArea:IsConnected(area) then
		-- Use unconnected areas only as a last resort
		cost = cost + 10 * dist
	elseif not area:IsVisible(temp_bot_pos) then
		-- Penalty for not visible areas
		cost = cost + 2 * dist
	end]]

	-- check height change
	local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange(area)
	if deltaZ >= compute_step_height then
		if deltaZ >= 64 then
			return -1 -- too high to reach
		end

		-- jumping is slower than flat ground
		cost = cost + 2 * dist
	elseif deltaZ < -2000 then
		return -1 -- too far to drop
	end

	return cost
end

local pathlength
function meta:UpdateBotPath()
	-- Nothing to kill
	if #self.PathableTargets == 0 then
		self:SetCurrentEnemy(NULL)
		self:ClearMovementTarget()
		return
	end

	local length = 10000 -- Increase this for really big maps
	local path, tpath, new_enemy

	loco = self.NB.loco
	--compute_pl = self
	compute_step_height = self:GetStepSize()

	--temp_bot_pos = self:EyePos()

	-- Find the target with the shortest route.
	-- This is presorted without path distance in the tick function so this won't always be accurate but it needs to be cheap.
	for i, ent in pairs(self.PathableTargets) do
		tpath = Path("Follow")
		tpath:SetMinLookAheadDistance(300)
		tpath:SetGoalTolerance(20)
		tpath:Compute(self.NB, ent:GetPos(), Compute)

		pathlength = tpath:GetLength()

		if tpath:IsValid() and pathlength < length then
			path = tpath
			length = pathlength
			new_enemy = ent
		end

		-- This amount of tries is enough.
		if i >= 4 --[[or length < 128]] then break end
	end

	self:SetCurrentEnemy(new_enemy)
	self:ClearMovementTarget()

	if not new_enemy then return end

	-- path:Draw() -- For debugging

	-- Find the first segment not immediately near us
	local goal = path:GetCurrentGoal()
	if not goal then return end

	self:SetMovementTarget(self:GetPos() + goal.forward * 32)

	-- Have to look ahead to the next segment for jumping, ducking, etc.
	if goal.length < 48 then
		goal = path:GetAllSegments()[2]
		if goal and (goal.type == 2 or goal.type == 3) then
			self.ShouldJump = true
		end
	end
end

function meta:EnemyChanged(old_enemy)
	self.TargetAcquireTime = CurTime()
	if not self.CurrentEnemy:IsValid() then
		self:OnTargetLost()
	end
end

concommand.Add("ms_createnavmesh", function(p)
	if p:IsSuperAdmin() and not game.IsDedicated() then
		if p:GetObserverMode() == OBS_MODE_NONE and p:IsOnGround() and p:OnGround() then
			for _, class in ipairs({"func_door*", "prop_door*"}) do
				for _, ent in pairs(ents.FindByClass(class)) do
					ent:Fire("open", "", 0)
					ent:Fire("kill", "", 1)
				end
			end
			for _, class in ipairs({"prop_physics*", "func_breakable", "func_physbox"}) do
				for _, ent in pairs(ents.FindByClass(class)) do
					ent:Remove()
				end
			end
			local ent = ents.Create("info_player_start")
			if ent:IsValid() then
				ent:SetPos(p:GetPos())
				ent:Spawn()
				timer.Simple(2, function() navmesh.BeginGeneration() end)
			end
		else
			print("You must be firmly planted on the ground.")
		end
	end
end)

concommand.Add("ms_createbot", function(p)
	if p:IsSuperAdmin() then
		if GAME_NTEAMS <= 1 then print("Not enough teams!") return end
		local botteam = math.random(1, GAME_NTEAMS)
		while botteam == p:Team() do botteam = math.random(1, GAME_NTEAMS) end
		ZSBOTS:CreateBot(botteam, nil)
	end
end)

-- Creating fields within a table avoids rehashing (although definitely not a performance boost, just a practice)
local ENT = {
	Type = "nextbot",
	Base = "base_nextbot",
	IsZsBot = true
}
-- Reminder, can't create self-references inside a table due to the object not existing yet, therefore this method should be defined only after the table's construct
function ENT:Initialize()
	self:AddEFlags(EFL_SERVER_ONLY + EFL_FORCE_CHECK_TRANSMIT)
	self:SetSolid(SOLID_NONE)
end

scripted_ents.Register(ENT, "zsbotnb")