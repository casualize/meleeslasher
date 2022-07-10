--CACHED GLOBALS
local math_min = math.min
local curtime = CurTime

local M_Entity = FindMetaTable("Entity")
local M_Player = FindMetaTable("Player")
local M_CMoveData = FindMetaTable("CMoveData")

local E_GetTable = M_Entity.GetTable
local E_GetDTFloat = M_Entity.GetDTFloat
local E_GetDTBool = M_Entity.GetDTBool
local P_GetActiveWeapon = M_Player.GetActiveWeapon
local P_GetWalkSpeed = M_Player.GetWalkSpeed
local P_SetRunSpeed = M_Player.SetRunSpeed
local M_SetVelocity = M_CMoveData.SetVelocity
local M_GetVelocity = M_CMoveData.GetVelocity
local M_SetMaxSpeed = M_CMoveData.SetMaxSpeed
local M_GetMaxSpeed = M_CMoveData.GetMaxSpeed
local M_SetMaxClientSpeed = M_CMoveData.SetMaxClientSpeed
local M_GetMaxClientSpeed = M_CMoveData.GetMaxClientSpeed
local M_GetForwardSpeed = M_CMoveData.GetForwardSpeed
local M_GetSideSpeed = M_CMoveData.GetSideSpeed

function GM:SetupMove(pl, move, cmd)
end

local fw, sd, pt, vel, mul
function GM:Move(pl, move)
	fw = M_GetForwardSpeed(move)
	if fw > 0 then 
		P_SetRunSpeed(pl, 140)
		--if SERVER then self:StaminaUpdate(pl,nil,true) end
		if P_GetActiveWeapon(pl).m_iState == STATE_ATTACK then
			P_SetRunSpeed(pl, P_GetWalkSpeed(pl))
			M_SetMaxSpeed(move, M_GetMaxSpeed(move) * 1.5)
			M_SetMaxClientSpeed(move, M_GetMaxClientSpeed(move) * 1.5)
		end
	else
		P_SetRunSpeed(pl, P_GetWalkSpeed(pl))
	end
end

function GM:OnPlayerHitGround(pl, inwater, hitfloater, speed)
	if speed > 64 then
		pl.LandSlow = true
	end
end

function GM:FinishMove(pl, move)
	pt = E_GetTable(pl)

	-- Simple anti bunny hopping. Flag is set in OnPlayerHitGround
	if pt.LandSlow then
		pt.LandSlow = false

		vel = M_GetVelocity(move)
		mul = 1 - 0.25 * (pt.FallDamageSlowDownMul or 1)
		vel.x = vel.x * mul
		vel.y = vel.y * mul
		M_SetVelocity(move, vel)
	end
end